require 'spec_helper'

describe Blitz::Curl::Performance do
before :each do
        @resource = double :Resource
        RestClient::Resource.stub(:new).and_return @resource
        #File.stub(:exists?).and_return true
        #File.stub(:read).and_return "test@example.com\nabc123"
        args = {
            :region => 'virginia',
            :steps => [ { :url => "http://www.example.com"}],
            :har => true
        }
        @performance = Blitz::Curl::Performance.new args
    end

    context "#queue" do
        before :each do
            @queue = double :Resource
            json = "{\"ok\":true, \"job_id\":\"j123\", \"status\":\"queued\", \"region\":\"virginia\"}"
            @resource.should_receive(:[]).with('/api/1/curl/execute').and_return @queue
            @queue.should_receive(:post).and_return json
            @queue = double :Resource
        end

        it "should set the region" do
            @performance.region.should be_nil
            @performance.queue
            @performance.region.should == 'virginia'
        end

        it "should set the job_id" do
            @performance.job_id.should be_nil
            @performance.queue
            @performance.job_id.should == 'j123'
        end
    end

    context "#result" do
        before :each do
            @queue = double :Resource
            json = "{\"ok\":true, \"job_id\":\"j123\", \"status\":\"queued\", \"region\":\"virginia\"}"
            @resource.should_receive(:[]).with('/api/1/curl/execute').and_return @queue
            @queue.should_receive(:post).and_return json
            @status = double :Resource
            json2 = "{\"ok\":true, \"status\":\"completed\", \"result\":{\"region\":\"virginia\", \"timeline\":[]}}"
            @resource.should_receive(:[]).with("/api/1/jobs/j123/status").and_return @status
            @status.should_receive(:get).and_return json2
            @performance.queue
        end

        it "should return a new Blitz::Curl::Performance::Result instance" do
            result = @performance.result
            result.should_not be_nil
            result.class.should == Blitz::Curl::Performance::Result
        end

        it "should return result with region virginia" do
            result = @performance.result
            result.region.should == 'virginia'
        end
    end

    context "#execute" do
        before :each do
            @queue = double :Resource
            json = "{\"ok\":true, \"job_id\":\"j123\", \"status\":\"queued\", \"region\":\"california\"}"
            @resource.should_receive(:[]).with('/api/1/curl/execute').and_return @queue
            @queue.should_receive(:post).and_return json
            @status = double :Resource
            json2 = "{\"ok\":true, \"status\":\"completed\", \"result\": #{File.read(
                File.expand_path("../../mocked_performance.json", __FILE__))} }"
            @resource.should_receive(:[]).with("/api/1/jobs/j123/status").and_return @status
            @status.should_receive(:get).and_return json2
        end

        it "should return a new Blitz::Curl::Performance::Result instance" do
            @performance.queue
            result = @performance.result
            result.should_not be_nil
            result.class.should == Blitz::Curl::Performance::Result
        end

        it "should return result with region virginia" do
            @performance.queue
            result = @performance.result
            result.region.should == 'virginia'
        end
    end
end
