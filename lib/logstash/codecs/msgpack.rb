# encoding: utf-8
require "logstash/codecs/base"
require "logstash/timestamp"

class LogStash::Codecs::Msgpack < LogStash::Codecs::Base
  config_name "msgpack"

  milestone 1

  config :format, :validate => :string, :default => nil

  public
  def register
    require "msgpack"
  end

  public
  def decode(data)
    begin
      # Msgpack does not care about UTF-8
      event = LogStash::Event.new(MessagePack.unpack(data))
      event["@timestamp"] = LogStash::Timestamp.at(event["@timestamp"]).utc if event["@timestamp"].is_a? Float
      event["tags"] ||= []
      if @format
        event["message"] ||= event.sprintf(@format)
      end
    rescue => e
      # Treat as plain text and try to do the best we can with it?
      @logger.warn("Trouble parsing msgpack input, falling back to plain text",
                   :input => data, :exception => e)
      event["message"] = data
      event["tags"] ||= []
      event["tags"] << "_msgpackparsefailure"
    end
    yield event
  end # def decode

  public
  def encode(event)
    # use normalize = true to make sure returned Hash is pure Ruby for
    # MessagePack#pack which relies on pure Ruby object recognition
    data = event.to_hash(normalize = true)
    # timestamp is serialized as a iso8601 string
    # merge to avoid modifying data which could have side effects if multiple outputs
    @on_event.call(MessagePack.pack(data.merge(LogStash::Event::TIMESTAMP => event.timestamp.to_iso8601)))
  end # def encode

end # class LogStash::Codecs::Msgpack
