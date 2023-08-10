# frozen_string_literal: true

module EmailServices
  class Create < ApplicationService
    def initialize(app_id:, from:, to:, cc:, subject:, text_part:, html_part:,
                   ignore_deny_list:, meta_values:)
      super()
      @app_id = app_id
      @from = from
      @to = to
      @cc = cc
      @subject = subject
      @text_part = text_part
      @html_part = html_part
      @ignore_deny_list = ignore_deny_list
      @meta_values = meta_values
    end

    # TODO: Check for validation errors
    # TODO: Check that at least one of html_part and text_part are non-null
    def call
      mail = Mail.new
      mail.from = from
      mail.to = to
      mail.cc = cc
      mail.subject = subject

      if text_part
        part = Mail::Part.new
        part.body = text_part
        mail.text_part = part
      end

      if html_part
        part = Mail::Part.new
        part.content_type = "text/html; charset=UTF-8"
        part.body = html_part
        mail.html_part = part
      end

      email = EmailServices::CreateFromData.new(
        to: mail.to,
        data: mail.to_s,
        app_id: app_id,
        ignore_deny_list: ignore_deny_list,
        meta_values: meta_values
      ).call

      success!
      email
    end

    private

    attr_reader :app_id, :from, :to, :cc, :subject, :text_part, :html_part,
                :ignore_deny_list, :meta_values
  end
end
