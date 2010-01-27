require 'hub'
require 'mocks'
require 'timeout'

HUB_URL = ENV['HUB_URL']
raise "Specify a hub URL by setting the HUB_URL environment variable." unless HUB_URL

def wait_for(timeout = 3)
  (timeout * 10).to_i.times do
    break if yield
    sleep 0.1
  end
end

def as_optional
  # TODO: record as optional spec failure
end

shared_examples_for "all hubs with a publisher and subscriber" do
  before(:all) do
    @hub = Hub.new(HUB_URL)
    @publisher = Publisher.new(@hub)
    @subscriber = Subscriber.new(@hub)
    @topic_url = ENV['TOPIC_URL'] || @publisher.content_url
  end

  before(:each) do
    @subscriber.on_request = lambda { |req, res| }
  end

  after(:all) do
    @publisher.stop
    @subscriber.stop
  end
end

def doRequest(opts = {})
  opts[:callback] = @subscriber.accept_callback_url unless opts.has_key?(:callback)
  opts[:topic] = @topic_url unless opts.has_key?(:topic)
  opts[:verify] = 'sync' unless opts.has_key?(:verify)
  opts[:verify_token] = Subscriber::VERIFY_TOKEN unless opts.has_key?(:verify_token)
  opts[:params] = nil unless opts.has_key?(:params)

  if (@request_mode == 'subscribe')
    @hub.subscribe(opts[:callback], opts[:topic], opts[:verify], opts[:verify_token], opts[:params])
  elsif (@request_mode == 'unsubscribe')
    @hub.unsubscribe(opts[:callback], opts[:topic], opts[:verify], opts[:verify_token], opts[:params])
  end
end

def get_publish_notification
  @request_mode = 'subscribe'
  doRequest.should be_a_kind_of(Net::HTTPNoContent)

  request = nil
  @subscriber.on_request = lambda { |req, res| request = req }

  @hub.publish(@topic_url)

  wait_for { request != nil }

  request.should_not be_nil
  return request
end


