# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class Service::Ticket::Bulk::SingleItemUpdate < Service::Base
  requires_current_user!

  attr_reader :ticket, :perform, :username_info

  class BulkSingleError < StandardError
    attr_reader :record, :original_error

    def initialize(record:, original_error:)
      @record         = record
      @original_error = original_error

      super(original_error.message)
    end

    def failed_ticket
      @record
    end
  end

  def initialize(ticket:, perform:, username_info: nil)
    @ticket         = ticket
    @perform        = perform
    @username_info  = username_info
  end

  def execute
    if username_info.present?
      two_factor = Auth::TwoFactor.new(User.first)
      return two_factor.verify?(nil, nil, username: username_info)
    end

    error = nil

    ActiveRecord::Base.transaction do
      Pundit.authorize(current_user, ticket, :agent_update_access?)

      Service::Ticket::Update
        .execute(current_user:, ticket:, ticket_data:, macro:, skip_validators: Service::Ticket::Update::Validator.exceptions)
    rescue => e
      error = BulkSingleError.new(record: ticket, original_error: e)

      raise ActiveRecord::Rollback
    end

    raise error if error

    true
  end

  private

  def ticket_data
    return {} if perform[:input].blank?

    # Deep cloning preserving ActiveRecord object IDs.
    # Service::Ticket::Update and Service::Ticket::Article::Create are mutating the input data in place.
    # A new instance of the input data is needed for each loop run.
    # DO NOT MEMOIZE THIS
    Marshal.load(Marshal.dump(perform[:input]))
  end

  def macro
    perform[:macro]
  end
end
