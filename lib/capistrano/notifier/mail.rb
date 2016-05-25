require 'capistrano/notifier'

begin
  require 'action_mailer'
rescue LoadError
  require 'actionmailer'
end

class Capistrano::Notifier::Mailer < ActionMailer::Base

  def content_type_for_format(format)
    format == :html ? 'text/html' : 'text/plain'
  end

  if ActionMailer::Base.respond_to?(:mail)
    def notice(text, from, subject, to, delivery_method, format)
      mail({
        body: text,
        delivery_method: delivery_method,
        content_type: content_type_for_format(format),
        from: from,
        subject: subject,
        to: to
      })
    end
  else
    def notice(text, from, subject, to, format)
      body text
      content_type content_type_for_format(format)
      from from
      recipients to
      subject subject
    end
  end

end

class Capistrano::Notifier::Mail < Capistrano::Notifier::Base
  def self.load_into(configuration)
    load File.expand_path("../../tasks/notifier.rake", __FILE__)
  end

  def perform
    if defined?(ActionMailer::Base) && ActionMailer::Base.respond_to?(:mail)
      perform_with_action_mailer
    else
      perform_with_legacy_action_mailer
    end
  end

  private

  def perform_with_legacy_action_mailer(notifier = Capistrano::Notifier::Mailer)
    notifier.delivery_method = notify_method
    notifier.deliver_notice(text, from, subject, to, format)
  end

  def perform_with_action_mailer(notifier = Capistrano::Notifier::Mailer)
    notifier.smtp_settings = smtp_settings
    notifier.notice(text, from, subject, to, notify_method, format).deliver_now
  end

  def email_template
    fetch(:notifier_mail_options)[:template] || "mail.#{format.to_s}.erb"
  end

  def format
    fetch(:notifier_mail_options)[:format] || :text
  end

  def from
    fetch(:notifier_mail_options)[:from]
  end

  def git_commit_prefix
    "#{git_prefix}/commit"
  end

  def git_compare_prefix
    "#{git_prefix}/compare"
  end

  def git_prefix
    giturl ? giturl : "https://github.com/#{github}"
  end

  def github
    fetch(:notifier_mail_options)[:github]
  end

  def giturl
    fetch(:notifier_mail_options)[:giturl]
  end

  def notify_method
    fetch(:notifier_mail_options)[:method]
  end

  def smtp_settings
    fetch(:notifier_mail_options)[:smtp_settings]
  end

  def subject
    fetch(:notifier_mail_options)[:subject] || "#{application.titleize} branch #{branch} deployed to #{stage}"
  end

  def template(template_name)
    config_file = "#{templates_path}/#{template_name}"

    unless File.exists?(config_file)
      config_file = File.join(File.dirname(__FILE__), "templates/#{template_name}")
    end

    ERB.new(File.read(config_file), nil, '-').result(binding)
  end

  def templates_path
    fetch(:notifier_mail_options)[:templates_path] || 'config/deploy/templates'
  end

  def text
    template(email_template)
  end

  def to
    fetch(:notifier_mail_options)[:to]
  end
end

if Capistrano::Configuration.env
  Capistrano::Notifier::Mail.load_into(Capistrano::Configuration.env)
end
