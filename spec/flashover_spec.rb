require "spec_helper"

describe Flashover do
  describe "incoming events" do
    it "should publish a message to redis" do
      redis = Object.new
      redis.should_receive(:publish).with("flashover:pubsub:test:sms", anything) { true }

      flashover = Flashover.new redis, "password"
      flashover.sms "hello" => "world"
    end

    it "should encrypt the payload" do
      Flashover::Crypto.any_instance.should_receive(:encrypt).with(anything) { "" }

      redis = Object.new
      redis.should_receive(:publish).with("flashover:pubsub:test:sms", anything) { true }

      flashover = Flashover.new redis, "password"
      flashover.sms "hello" => "world"
    end
  end
end
