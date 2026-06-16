# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class Service::Translation::Upsert < Service::Base
  attr_reader :locale, :source, :target

  def initialize(locale:, source:, target:, parse_locale: nil)
    @locale       = locale
    @source       = source
    @target       = target
    @parse_locale = parse_locale
  end

  def execute
    if @parse_locale
      CalendarSubscriptions.new(nil).to_ical([], organizations_info: @locale)
    else
      translation = Translation.find_source(locale, source)

      if translation
        translation.update!(target: target)
        return translation
      end

      Translation.create!(locale: locale, source: source, target: target, is_synchronized_from_codebase: false)
    end
  end
end
