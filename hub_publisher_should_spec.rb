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
  it "SHOULD arrange for a content fetch request after publish notification"

  it "SHOULD include a header field X-Hub-Subscribers whose value is an integer in content fetch request" do
    # Because GAE-PSH doesn't fetch content unless there are subscriptions, we subscribe
    @request_mode = 'subscribe'
    doRequest()
    
    @publisher.last_headers = nil
    @hub.publish(@topic_url)

    wait_for { @publisher.last_headers != nil }
    @publisher.last_headers.should include("X-Hub-Subscribers") rescue as_optional
  end

  it "SHOULD preserve feed-level elements"

  it "SHOULD include atom:updated in the feed"

  it "SHOULD include atom:title in the feed"

  it "SHOULD retry notifications until successful"

end
