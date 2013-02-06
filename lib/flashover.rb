class Flashover

  VERSION = "0.0.1"

  MESSAGE_TYPES = [
    :sms,
    :phone,
    :email,
    :page_view,
    :generic,
    :backup
  ].freeze

  attr_accessor :redis, :environment

  def initialize redis, passphrase, salt
    @redis = redis
    @crypto = Crypto.new passphrase, salt
  end

  # 'type' dictates the message pipeline payload is shoved down
  # can be:
  # -> :sms
  # -> :phone_call
  # -> :email
  # -> :page_view
  # -> :generic
  def event type, payload
    begin
      @redis.publish(convert_symbol_to_channel(type), build_payload(payload))
      true
    rescue Errno::ETIMEDOUT => ex
      Airbrake.notify(ex)
      Rails.logger.error "Flashover TIMEOUT @ #{Time.now.ctime}"
      false
    rescue => ex
      Airbrake.notify(ex)
      Rails.logger.error "BANG @ Flashover#event => #{ex.class} -> '#{ex.message}'"
      false
    end
  end

  def listen &blk
    raise MaryPoppins.new("block must have two args") unless blk.arity == 2

    @redis.subscribe(redis_message_types) do |on|
      on.message do |channel, message|
        yield convert_channel_to_symbol(channel), parse_message(message)
      end
    end
  end

  MESSAGE_TYPES.each do |message_type|
    define_method message_type do |payload|
      event message_type, payload
    end
  end

  private
  def encrypt(plaintext)
    @crypto.encrypt plaintext
  end

  def decrypt(ciphertext)
    @crypto.decrypt ciphertext
  end

  def build_payload(payload)
    encrypt JSON.generate payload
  end

  def parse_message(message)
    JSON.parse(decrypt message)
  end

  def build_message_from_payload(payload)
    encrypt JSON.generate(payload)
  end


  def redis_message_types
    @redis_message_types ||= MESSAGE_TYPES.map do |message_type|
      "flashover:pubsub:#{environment}:#{message_type.to_s}"
    end
  end

  def convert_channel_to_symbol channel
    channel.split(":").last.to_sym
  end

  def convert_symbol_to_channel symbol
    "flashover:pubsub:#{environment}:#{symbol.to_s}"
  end

  def environment
    @environment || ENV["FLASHOVER_ENV"] || ENV["RAILS_ENV"] || "development"
  end

  class Crypto

    def initialize(passphrase, salt)
      raise MaryPoppins.new("salt needs to be 8 chars long") unless salt.length == 8
      @passphrase = passphrase
      @salt = salt
    end

    def encrypt plaintext
      encryptor = OpenSSL::Cipher::Cipher.new 'AES-256-CBC'
      encryptor.encrypt
      encryptor.pkcs5_keyivgen @passphrase, @salt

      encrypted = encryptor.update plaintext
      encrypted << encryptor.final
    end

    def decrypt ciphertext
      decryptor = OpenSSL::Cipher::Cipher.new 'AES-256-CBC'
      decryptor.decrypt
      decryptor.pkcs5_keyivgen @passphrase, @salt

      decrypted = decryptor.update ciphertext
      decrypted << decryptor.final
    end
  end

  class MaryPoppins < StandardError; end
end
