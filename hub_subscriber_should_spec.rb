require 'common'

# Subscription and Unsubscription
# http://pubsubhubbub.googlecode.com/svn/trunk/pubsubhubbub-core-0.2.html#subscribing
#
# Section 6
#

shared_examples_for "fully compliant hubs that obey request semantics" do
  it_should_behave_like "all hubs with a publisher and subscriber"

  # Subscriber Subscription/Unsubscription Requests - Core Requirements
  # http://pubsubhubbub.googlecode.com/svn/trunk/pubsubhubbub-core-0.2.html#anchor5
  # ===============================================================================
  #
 
  # Section 6.1
  it "SHOULD NOT return an error if the verify token is omitted from the request" do
    doRequest(:verify_token => nil).should_not be_a_kind_of(Net::HTTPClientError)
  end

  # Section 6.1.1
  # This line intentionally left blank.

  # Section 6.1.2
  it "SHOULD return a description of an error in the response body in plain text" do
    response = doRequest(:callback => 'invalid url')
    response.content_type.should == 'text/plain'
    response.content_length.should > 0
    response.body.should match(/\W*ur[li]\W*/i)
  end

  # Section 6.2.1
  it "SHOULD retry if the subscriber returns a non-success (2xx) response code in asynchronous mode" do
    attempts = 0

    @subscriber.on_request = lambda { |req, res|
       attempts += 1
       { 'status' => 500, 'body' => 'ERRROR ERRROR' }
    }

    doRequest(:verify => 'async', :params => {'hub.debug.retry_after' => 1})

    # Give the hub 2 seconds to retry each time. We've included the
    # debug.retry_after parameter to specify a retry interval of 1 second.
    wait_for(6) { attempts >= 3 }

    attempts.should >= 3
  end
end

describe Hub do
  context "when handling subscription requests" do
    before(:all) { @request_mode = 'subscribe' }
    it_should_behave_like "fully compliant hubs that obey request semantics"
  end

  context "when handling unsubscription requests" do
    before(:all) { @request_mode = 'unsubscribe' }
    it_should_behave_like "fully compliant hubs that obey request semantics"
  end
end
