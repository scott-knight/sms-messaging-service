class SmsMessageSerializer
  include JSONAPI::Serializer
  SMS_MESSAGES_PATH = "/#{API_VERSION}/sms_messages"

  attributes :phone_number, :message, :message_uuid, :status, :status_code,
             :total_tries, :url_domain, :url_path,
             :created_at, :updated_at, :discarded_at

  link :self do |object|
    { url: "#{SMS_MESSAGES_PATH}/#{object.id}" }
  end
end
