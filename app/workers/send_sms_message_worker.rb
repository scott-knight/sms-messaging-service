class SendSmsMessageWorker
  include Sidekiq::Worker

  attr_reader :provider, :provider1_count, :provider2_count, :retry_on_fail,
              :send_to_provider1, :sms_message_id, :urls, :weighted_ratio

  def perform(sms_message_id, provider: nil, retry_on_fail: true, weight1: 30, weight2: 70)
    validate_redis_cache
    call_variables(sms_message_id, provider, weight1, weight2)
    determine_provider
    send_message
  end

  private

  def call_variables(id, provider, w1, w2, retry_on_fail)
    @provider1_count = REDIS.get('provider1_count').to_i
    @provider2_count = REDIS.get('provider2_count').to_i
    @provider        = provider
    @retry_on_fail   = retry_on_fail
    @sms_message_id  = id
    @weighted_ratio  = w1.fdiv w2
  end

  def determine_provider_from_variable
    @send_to_provider1 = provider == 1
  end

  def determine_provider
    return determine_provider_from_variable if provider_valid?

    if provider1_count + provider2_count == 0
      if weighted_ratio <= 1.0
        REDIS.incr('provider2_count')
        @send_to_provider1 = false
      else
        REDIS.incr('provider1_count')
        @send_to_provider1 = true
      end
    else
      r1 = provider1_count.succ.fdiv provider2_count
      r2 = provider1_count.fdiv provider2_count.succ

      if (r1 - weighted_ratio).abs <= (r2 - weighted_ratio).abs
        REDIS.incr('provider1_count')
        @send_to_provider1 = true
      else
        REDIS.incr('provider2_count')
        @send_to_provider1 = false
      end
    end
  end

  def provider_valid?
    provider.present? && [1, 2].include?(provider)
  end

  def send_message
    MessageSubmitterService.new(
      provider: (send_to_provider1 ? 1 : 2),
      sms_message_id: sms_message_id,
      retry_on_fail: retry_on_fail
    ).submit_message
  end

  def validate_redis_cache
    count = REDIS.get('provider2_count')

    if count.blank? || count.to_i > 9999
      REDIS.set('provider1_count', 0)
      REDIS.set('provider2_count', 0)
    end
  end
end