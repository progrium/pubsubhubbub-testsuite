require 'common'

# Subscription and Unsubscription
# http://pubsubhubbub.googlecode.com/svn/trunk/pubsubhubbub-core-0.2.html#subscribing
#
# Section 6
#

shared_examples_for "compliant hubs that obey request semantics" do
  it_should_behave_like "all hubs with a publisher and subscriber"

  # Subscriber Subscription/Unsubscription Requests - Core Requirements
  # http://pubsubhubbub.googlecode.com/svn/trunk/pubsubhubbub-core-0.2.html#anchor5
  # ===============================================================================

  # Section 6.1
  context "when handling incoming requests" do
    it "MUST accept POST requests for subscription requests" do
      doRequest.should be_a_kind_of(Net::HTTPSuccess)
    end

    it "MUST reject non-POST requests for subscription requests" do
      uri = @hub.endpoint.dup
      uri.query = "hub.callback=#{@subscriber.accept_callback_url}&" +
                  "hub.topic=#{@topic_url}&hub.mode=subscribe"

      Net::HTTP.start(uri.host, uri.port) do |http|
        req = Net::HTTP::Get.new(uri.request_uri)
        http.request(req).should be_a_kind_of(Net::HTTPClientError)
      end
    end

    it "MUST reject POST bodies that are not application/x-www-form-urlencoded" do
      uri = @hub.endpoint.dup
      uri.query = "hub.mode=subscribe&hub.topic=#{@topic_url}&hub.callback=#{@subscriber.accept_callback_url}"
      
      Net::HTTP.start(uri.host, uri.port) do |http|
        req = Net::HTTP::Post.new(uri.request_uri)
        req['Content-type'] = 'application/json'
        req.body = '{"hub.callback":"' + @subscriber.accept_callback_url + '",' +
                    '"hub.mode":"subscribe","hub.topic":"' + @topic_url + '"}'

        http.request(req).should be_a_kind_of(Net::HTTPClientError)
      end
    end

    it "MUST return an error if the callback parameter is omitted from the request" do
      doRequest(:callback => nil).should be_a_kind_of(Net::HTTPClientError)
    end

    it "MUST return an error if the topic parameter is omitted from the request" do
      doRequest(:topic => nil).should be_a_kind_of(Net::HTTPClientError)
    end

    it "MUST return an error if the verify keyword is omitted from the request" do
      doRequest(:verify => nil).should be_a_kind_of(Net::HTTPClientError)
    end

    it "MUST return an error if neither sync nor async are provided as values to any verify parameter" do
      doRequest(:verify => 'invalid').should be_a_kind_of(Net::HTTPClientError)
    end

    it "MUST ignore verify keywords it does not understand" do
      doRequest(:verify => ['sync', 'foobar']).should be_a_kind_of(Net::HTTPSuccess)
    end

    it "MUST make a synchronous verification attempt if only the 'sync' verify mode is allowed" do
      request = nil
      @subscriber.on_request = lambda { |req, res| request = req; nil }
      doRequest.should be_a_kind_of(Net::HTTPNoContent)

      # request should already be non-nil. Don't wait for it to change.
      # This is not 100% fool-proof, since there is a small chance that the hub has lied to us, sent
      # an HTTP 204 response, and then made the request very quickly.
      #
      # In order to fix this test properly, we'd need to tell subscribe() to
      # actually look for the callback.

      request.should_not be_nil
    end

    it "MUST make an asynchronous verification attempt if only the 'async' verify mode is allowed" do
      request = nil
      @subscriber.on_request = lambda { |req, res| request = req; nil }

      doRequest(:verify => 'async').should be_a_kind_of(Net::HTTPAccepted)

      # As with the previous test, the timing is a bit tricky here, but without ripping the whole
      # stack apart, let's build in some assumptions and assume that for an async request, the HTTP
      # request won't have been sent instantaneously, but will be sent in some small amount of time.

      request.should be_nil

      wait_for { request != nil }

      request.should_not be_nil
    end

    it "MUST not reject multiple verify keywords" do
      doRequest(:verify => ['async', 'sync', 'other']).should be_a_kind_of(Net::HTTPSuccess)
    end
  end

  # Section 6.1.1
  context "when preparing the verification request" do
    it "MUST reject topic URLs that contain a fragment" do
      doRequest(:topic => "http://example.com/path#fragment").should be_a_kind_of(Net::HTTPClientError)
    end

    it "MUST reject callback URLs that contain a fragment" do
      doRequest(:callback => "http://example.com/path#fragment").should be_a_kind_of(Net::HTTPClientError)
    end

    it "MUST preserve the query string during verification" do
      query_string = nil
      @subscriber.on_request = lambda { |req, res| query_string = req.query_string; nil }

      doRequest(:callback => @subscriber.accept_callback_url + "?z=y&a=b").should be_a_kind_of(Net::HTTPSuccess)

      query_string.should match(/^z=y&a=b&/)
    end

    it "MUST NOT overwrite existing query string parameters" do
      query_string = nil
      @subscriber.on_request = lambda { |req, res| query_string = req.query_string; nil }

      callback_url = @subscriber.accept_callback_url + "?hub.challenge=imahacker"
      doRequest(:callback => callback_url).should be_a_kind_of(Net::HTTPSuccess) 

      query_string.should match(/^hub\.challenge=imahacker&/)
    end

    it "MUST append any new parameters to the end of the existing callback URL" do
      query_string = nil
      @subscriber.on_request = lambda { |req, res| query_string = req.query_string; nil }

      callback_url = @subscriber.accept_callback_url + "?x=y"
      doRequest(:callback => callback_url).should be_a_kind_of(Net::HTTPSuccess)

      query_string.should match(/^x=y&/)
      params = CGI.parse(query_string.sub(/^x=y&/, ''))
      params.should have_key('hub.challenge')
      params.should have_key('hub.verify_token')
      params.should have_key('hub.topic')
      params.should have_key('hub.mode')
    end

    it "MUST use an HTTP GET request to the callback URL" do
      request = nil
      @subscriber.on_request = lambda { |req, res| request = req; nil }

      doRequest.should be_a_kind_of(Net::HTTPSuccess)

      request.request_method.should == 'GET'
    end

    it "MUST NOT include query-string parameters in the body of the verification request" do
      request = nil
      @subscriber.on_request = lambda { |req, res| request = req; nil }

      doRequest.should be_a_kind_of(Net::HTTPSuccess)

      request.body.should be_nil
    end
  end

  # Section 6.1.2
  context "when determining the outcome of the request" do
    it "MUST return 204 No Content if the subscription was created and verified" do
      doRequest.should be_a_kind_of(Net::HTTPNoContent)
    end

    it "MUST return 202 Accepted if the request is pending" do
      doRequest(:verify => 'async').should be_a_kind_of(Net::HTTPAccepted)
    end

    it "MUST return a client error (4xx) in case the client has made an invalid request" do
      doRequest(:callback => 'invalid url').should be_a_kind_of(Net::HTTPClientError)
    end
   
    it "MUST complete verification before returning a response in synchronous mode" do
      request_time = nil
      @subscriber.on_request = lambda { |req, res| request_time = Time.now.to_f; nil }
      doRequest.should be_a_kind_of(Net::HTTPNoContent)

      # This is totally janky, but more or less does the trick.
      request_time.should < Time.now.to_f
    end
  end

  # Hub Verification of Subscription Intent
  # http://pubsubhubbub.googlecode.com/svn/trunk/pubsubhubbub-core-0.2.html#verifysub
  # =================================================================================

  # Section 6.2
  context "when verifying the subscription request" do
    it "MUST verify subscriber intent with a GET request to the URL specified by hub.callback" do
      request = nil

      @subscriber.on_request = lambda { |req, res| request = req; nil }
      doRequest.should be_a_kind_of(Net::HTTPNoContent)

      request.should_not be_nil
      request.request_method.should == 'GET'
    end

    it "MUST include a matching hub.mode parameter" do
      parameters = nil

      @subscriber.on_request = lambda { |req, res| parameters = CGI.parse(req.query_string); nil }
      doRequest.should be_a_kind_of(Net::HTTPNoContent)

      parameters.should have_key("hub.mode")
      parameters['hub.mode'].should == [@request_mode]
    end

    it "MUST include a matching hub.topic parameter in the verification request" do
      parameters = nil

      @subscriber.on_request = lambda { |req, res| parameters = CGI.parse(req.query_string); nil }
      doRequest(:topic => 'http://example.com/forced_topic').should be_a_kind_of(Net::HTTPNoContent)

      parameters.should have_key('hub.topic')
      parameters['hub.topic'].should == ['http://example.com/forced_topic']
    end

    it "MUST include a matching hub.verify_token in the verification request" do
      parameters = nil

      @subscriber.on_request = lambda { |req, res| parameters = CGI.parse(req.query_string); nil }
      doRequest.should be_a_kind_of(Net::HTTPNoContent)

      parameters.should have_key('hub.verify_token')
      parameters['hub.verify_token'].should == [Subscriber::VERIFY_TOKEN]
    end

    it "MUST NOT include a hub.verify_token in the verification request if none was provided" do
      parameters = nil

      @subscriber.on_request = lambda { |req, res| parameters = CGI.parse(req.query_string); nil }
      doRequest(:verify_token => nil).should be_a_kind_of(Net::HTTPNoContent)

      parameters.should_not have_key('hub.verify_token')
    end

    it "MUST include a hub.challenge parameter" do
      parameters = nil

      @subscriber.on_request = lambda { |req, res| parameters = CGI.parse(req.query_string); nil }
      doRequest.should be_a_kind_of(Net::HTTPNoContent)

      parameters.should have_key('hub.challenge')
      parameters['hub.challenge'].size.should == 1
      parameters['hub.challenge'].first.length.should > 0
    end

    it "MUST accept a successful HTTP response with the challenge parameter in the response body" do
      doRequest.should be_a_kind_of(Net::HTTPNoContent)
    end

    it "MUST reject a successful HTTP response without the challenge parameter in the response body" do
      @subscriber.on_request = lambda { |req, res|
        {'status' => 200, 'body' => 'NOT THE CHALLENGE'}
      }
      doRequest.should be_a_kind_of(Net::HTTPClientError)
    end

    it "MUST reject an unsuccessful HTTP 404 Not Found response" do
      @subscriber.on_request = lambda { |req, res| {'status' => 404} }
      doRequest.should be_a_kind_of(Net::HTTPClientError)
    end

    it "MUST reject all non-success (2xx) response codes in synchronous mode" do
      invalid_status_codes = [300..307, 400..417, 500..505].map { |i| i.entries }.flatten

      invalid_status_codes.each do |code|
        @subscriber.on_request = lambda { |req, res| {'status' => code} }
        doRequest.should be_a_kind_of(Net::HTTPClientError)
      end
    end

    it "MUST NOT retry if the callback returns a 404 Not Found response" do
      attempts = 0
      @subscriber.on_request = lambda { |req, res|
        attempts += 1
        { 'status' => 404, 'body' => "I don't know what you're talking about." }
      }

      doRequest(:verify => 'async', :params => {'hub.debug.retry_after' => 1})

      # Wait a few seconds for the hub to retry. To test a live hub, this delay
      # must be increased to a sufficiently long amount of time to detect the retry.
      wait_for(3) { attempts > 1 }

      attempts.should == 1
    end

    it "MUST NOT change subscription state if asynchronous confirmations fail after an arbitrary number of retries" do
      sub_status = @hub.subscription_status(@topic_url, @subscriber.accept_callback_url)
      sub_status.should == 'none'

      attempts = 0
      @subscriber.on_request = lambda { |req, res|
        attempts += 1
        { 'status' => 500, 'body' => 'Internal Server Error' }
      }
      doRequest(:verify => 'async', :params => {'hub.debug.retry_after' => 1})

      wait_for(6) { attempts >= 3 }
      attempts.should >= 3

      sub_status = @hub.subscription_status(@topic_url, @subscriber.accept_callback_url)
      sub_status.should == 'none'
    end
  end
end

describe Hub do
  context "when handling subscription requests" do
    before(:all) { @request_mode = 'subscribe' }
    it_should_behave_like "compliant hubs that obey request semantics"

    # Section 6.1.2
    it "MUST NOT activate an inactive subscription without verifying the request" do
      sub_status = @hub.subscription_status(@topic_url, @subscriber.accept_callback_url)
      sub_status.should == 'none'

      @subscriber.on_request = lambda { |req, res| {'status' => 500} }

      doRequest.should be_a_kind_of(Net::HTTPClientError)

      new_sub_status = @hub.subscription_status(@topic_url, @subscriber.accept_callback_url)
      new_sub_status.should == 'none'
    end

    it "MUST allow re-subscription for an active subscription" do
      sub_status = @hub.subscription_status(@topic_url, @subscriber.accept_callback_url)
      sub_status.should == 'none'

      doRequest.should be_a_kind_of(Net::HTTPNoContent)
      @hub.subscription_status(@topic_url, @subscriber.accept_callback_url).should == 'subscribed'

      doRequest.should be_a_kind_of(Net::HTTPNoContent)
      @hub.subscription_status(@topic_url, @subscriber.accept_callback_url).should == 'subscribed'
    end
  end

  context "when handling unsubscription requests" do
    before(:all) { @request_mode = 'unsubscribe' }
    it_should_behave_like "compliant hubs that obey request semantics"

    # Section 6.1.2
    it "MUST allow unsubscription from an active subscription" do
      doRequest.should be_a_kind_of(Net::HTTPNoContent)
      @hub.subscription_status(@topic_url, @subscriber.accept_callback_url).should == 'subscribed'

      doRequest(:mode => 'unsubscribe').should be_a_kind_of(Net::HTTPNoContent)
      @hub.subscription_status(@topic_url, @subscriber.accept_callback_url).should == 'none'
    end

    it "MUST NOT de-activate a previously active subscription without verifying the request" do
      doRequest.should be_a_kind_of(Net::HTTPNoContent)
      @hub.subscription_status(@topic_url, @subscriber.accept_callback_url).should == 'subscribed'

      @subscriber.on_request = lambda { |req, res| {'status' => 500} }
      doRequest(:mode => 'unsubscribe').should be_a_kind_of(Net::HTTPClientError)
      @hub.subscription_status(@topic_url, @subscriber.accept_callback_url).should == 'subscribed'
    end
  end
end
