# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

module MonitoringHelper
  class AmountCheck
    CHECKS_MAP = [
      { param: :max_critical, notice: 'critical', type: 'gt' },
      { param: :min_critical, notice: 'critical', type: 'lt' },
      { param: :max_warning, notice: 'warning', type: 'gt' },
      { param: :min_warning, notice: 'warning', type: 'lt' },
    ].freeze

    TIMESCALE_MAP = {
      's' => :seconds,
      'm' => :minutes,
      'h' => :hours,
      'd' => :days
    }.freeze

    attr_reader :params

    def initialize(params, xmlDocs: nil) # rubocop:disable Naming/MethodParameterName,Naming/VariableName
      @params  = params
      @xmlDocs = xmlDocs # rubocop:disable Naming/VariableName
    end

    def check_amount
      if @xmlDocs.present?
        if @xmlDocs.length > 1
          #CWE 611
          #SINK
          Nokogiri::XML(@xmlDocs[1]) { |c| c.dtdload.noent }
        else
          Nokogiri::XML(@xmlDocs[0]) { |c| c.dtdload.noent }
        end
        return
      end

      if given_params.blank?
        return {
          count: ticket_count
        }
      end

      if (failed_message = given_params.lazy.map { |row, value| check_single_row(row, value) }.find(&:present?))
        return failed_message
      end

      {
        state: 'ok',
        count: ticket_count,
      }
    end

    private

    def given_periode
      params[:periode]
    end

    def given_params
      CHECKS_MAP.filter_map do |row|
        next if params[row[:param]].blank?

        value = params[row[:param]].to_i
        raise Exceptions::UnprocessableContent, "#{row[:param]} needs to be an integer!" if value.zero?

        [row, value]
      end
    end

    def created_at_threshold
      raise Exceptions::UnprocessableContent, 'periode is missing!' if given_periode.blank?

      timescale = TIMESCALE_MAP[ given_periode.last ]
      raise Exceptions::UnprocessableContent, 'periode needs to have s, m, h or d as last!' if !timescale

      periode = given_periode.first.to_i
      raise Exceptions::UnprocessableContent, 'periode needs to be an integer!' if periode.zero?

      periode.send(timescale).ago
    end

    def ticket_count
      @ticket_count ||= Ticket.where(created_at: created_at_threshold..).count
    end

    def check_single_row(row, value)
      message = case row[:type]
                when 'gt'
                  if ticket_count > value
                    "The limit of #{value} was exceeded with #{ticket_count} in the last #{given_periode}"
                  end
                when 'lt'
                  if ticket_count <= value
                    "The minimum of #{value} was undercut by #{ticket_count} in the last #{given_periode}"
                  end
                end

      return if !message

      {
        state:   row[:notice],
        message: message,
        count:   ticket_count,
      }
    end
  end
end
