require 'common'

describe Hub, "interface for publishers" do
  it_should_behave_like "all hubs with a publisher and subscriber"

  # Section 7.5
  context "aggregation" do
    it "MUST return an error code if multiple hub.secret values are provided for subscriptions with the same hub.callback URL" do
      @request_mode = 'subscribe'
      doRequest(:params => {'hub.secret' => 'firstsecret'}).should be_a_kind_of(Net::HTTPNoContent)
      doRequest(:params => {'hub.secret' => 'secondsecret'}).should be_a_kind_of(Net::HTTPClientError)
    end

    it "SHOULD reproduce all elements from the source feed inside the atom:source element"

    it "MUST reproduce the atom:id value exactly"

    it "MUST include an atom:source element inside the atom:entry element"

    it "SHOULD include the atom:title element with a rel='self' value in the atom:source element"

    it "SHOULD include the atom:link element with a rel='self' value in the atom:source element"
  end

end
