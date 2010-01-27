require 'common'

# Publishing
# http://pubsubhubbub.googlecode.com/svn/trunk/pubsubhubbub-core-0.2.html#publishing
#
# Section 7
#

describe Hub, "interface for publishers" do
  it_should_behave_like "all hubs with a publisher and subscriber"

  # New Content Notification Requests - Core Requirements
  # http://pubsubhubbub.googlecode.com/svn/trunk/pubsubhubbub-core-0.2.html#anchor9
 
  # Section 7.1
  it "SHOULD arrange for a content fetch request after publish notification" do
    request = nil
    @publisher.on_request = lambda { |req, res| request = req }

    publish = get_publish_notification

    wait_for { request != nil }
    request.should_not be_nil

    request.method.should == 'GET'
  end

  it "SHOULD include a header field X-Hub-Subscribers whose value is an integer in content fetch request" do
    # Because GAE-PSH doesn't fetch content unless there are subscriptions, we subscribe
    @request_mode = 'subscribe'
    doRequest()
    
    @publisher.last_headers = nil
    @hub.publish(@topic_url)

    wait_for { @publisher.last_headers != nil }
    @publisher.last_headers.should include("X-Hub-Subscribers") rescue as_optional
  end

  it "SHOULD preserve feed-level elements" do
    publish = get_publish_notification
    pending 'verify preservation of feed-level elements'
  end

  it "SHOULD include atom:updated in the feed" do
    publish = get_publish_notification
    pending 'verify presence of atom:updated'
  end

  it "SHOULD include atom:title in the feed" do
    publish = get_publish_notification
    pending 'verify presence of atom:title'
  end

  it "SHOULD retry notifications until successful" do
    @request_mode = 'subscribe'
    doRequest()

    attempts = 0
    request = nil
    @subscriber.on_request = lambda { |req, res|
      request = req
      attempts += 1
      if attempts >= 2
        nil # allow the default (successful) response
      else
        {'status' => '500', 'body' => 'temporarily broken'}
      end
    }

    @hub.publish(@topic_url)

    wait_for { attempts >= 2 }
    pending 'check to ensure that the content notification came through'
  end

end
