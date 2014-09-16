require 'spec_helper'
require 'json'

describe Blitz::Command::Curl do

    let(:sprint_data)  {
        {
            'line'=>"GET / HTTP/1.1",
            'method'=>"GET",
            'url'=>"www.example.com",
            'content'=>"",
            'status'=>200,
            'message'=>"OK",
            'headers'=> {
                "User-Agent"=>"blitz.io; 5f691b@11.22.33.250",
                "Host"=>"blitz.io",
                "X-Powered-By"=>"blitz.io",
                "X-User-ID"=>"5f6938a60e",
                "X-User-IP"=>"44.55.66.250"
            }
        }
    }

    def mocked_sprint_request
        Blitz::Curl::Sprint::Request.new(sprint_data)
    end

    def mocked_sprint_args
        {
            "steps"=>[{"url"=>"http://blitz.io"}],
            "region"=>"california",
            "dump-header"=>"/mocked/path/head.txt",
            "verbose"=>true
        }
    end

    def mocked_sprint
        sprint = {
         'result' => {
             'region'=>"california",
             'duration'=> 0.39443,
             'steps'=>[
                  'connect'=>0.117957,
                  'duration'=>0.394431,
                  'request' => sprint_data,
                  'response' => sprint_data
              ]
         }
        }
        Blitz::Curl::Sprint::Result.new(sprint)
    end

    def mocked_rush
      rush = {
        'result' => {
            'region' => 'california',
            'timeline' => [
                  'timestamp' => 1.50353,
                  'volume' => 2,
                  'duration' => 0.42632,
                  'executed' => 2,
                  'timeouts' => 0,
                  'errors' => 0,
                  'steps' => [
                    'duration' => 0.0,
                    'connect' => 0.0,
                    'errors' => 0,
                    'timeouts' => 5,
                    'asserts' => 0
                  ]
            ]
        }
      }
      Blitz::Curl::Rush::Result.new(rush)
    end
    
    def mocked_performance_args
        {
            "steps" => [{"url" => "http://5.184.109.209:8080"}],
            "har" => true,
            "screenshot-file" => "file.png",
            "har-file" => "har.json"
        }
    end
    
    def mocked_performance
        performance = { 'result' => JSON.parse(File.read(
                File.expand_path("../../mocked_performance.json", __FILE__)))}
        Blitz::Curl::Performance::Result.new performance, 'dummy_job_id'
    end
    
    context "#print_sprint_header" do
        def check_print_sprint_header path="/mocked/path/head.txt"
            request = mocked_sprint_request
            symbol = "> "
            mode = 'w'
            obj = Blitz::Command::Curl.new
            yield(obj, path, mode)
            obj.send(:print_sprint_header, request, path, symbol, mode)
        end
        it "should prints header to console when path is '-'" do
            check_print_sprint_header("-") {|obj, path, mode|
                obj.should_receive(:puts).with("> GET / HTTP/1.1")
                obj.should_receive(:puts).with("> User-Agent: blitz.io; 5f691b@11.22.33.250\r\n")
                obj.should_receive(:puts).with("> Host: blitz.io\r\n")
                obj.should_receive(:puts).with("> X-Powered-By: blitz.io\r\n")
                obj.should_receive(:puts).with("> X-User-ID: 5f6938a60e\r\n")
                obj.should_receive(:puts).with("> X-User-IP: 44.55.66.250\r\n")
                obj.should_receive(:puts).with()
            }
        end
        it "should warn user if it can not open the file" do
            check_print_sprint_header() {|obj, path, mode|
                File.should_receive(:open).with(path, mode).and_raise("No such file or directory - #{path}")
                obj.should_receive(:puts).with("\e[31mNo such file or directory - #{path}\e[0m")
            }
        end
        it "should print request headers to file" do
            check_print_sprint_header() {|obj, path, mode|
                file = double('file')
                File.should_receive(:open).with(path, mode).and_yield(file)
                file.should_receive(:puts).with("")
                file.should_receive(:puts).with("GET / HTTP/1.1")
                file.should_receive(:puts).with("User-Agent: blitz.io; 5f691b@11.22.33.250")
                file.should_receive(:puts).with("Host: blitz.io")
                file.should_receive(:puts).with("X-Powered-By: blitz.io")
                file.should_receive(:puts).with("X-User-ID: 5f6938a60e")
                file.should_receive(:puts).with("X-User-IP: 44.55.66.250")
            }
        end
    end

    context "#csv_rush_result" do

      it "should check if the rush results get dumped in csv format" do
        file = CSV.open('blitztest.csv', 'w')

        result = mocked_rush
        obj = Blitz::Command::Curl.new
        obj.send(:csv_rush_result, file, result, nil)
        file.close

        file = CSV.open('blitztest.csv', 'r').read()
        output = file.last
        timeline = result.timeline.last

        output[0].to_f.should eq(timeline.timestamp)
        output[1].to_f.should eq(timeline.volume)
        output[2].to_f.should eq(timeline.duration)
        output[3].to_f.should eq(timeline.hits)
        output[4].to_f.should eq(timeline.timeouts)

        File.delete('blitztest.csv')
      end
    end

    context "#print_sprint_result" do
        def check_print_sprint_result args
            result = mocked_sprint
            obj = Blitz::Command::Curl.new
            yield(obj, result)
            obj.send(:print_sprint_result, args, result)
        end

        it "should not dump-header and verbose when they are not available" do
            args = mocked_sprint_args
            args.delete "verbose"
            args.delete "dump-header"
            check_print_sprint_result(args){|obj, result|
                obj.should_receive(:puts).with("Transaction time \e[32m394 ms\e[0m")
                obj.should_receive(:puts).with()
                obj.should_receive(:puts).with("> GET www.example.com")
                obj.should_receive(:puts).with("< 200 OK in \e[32m394 ms\e[0m")
                obj.should_receive(:puts).with()
            }
        end
        it "should dump-header and verbose when both are available" do
            check_print_sprint_result(mocked_sprint_args){|obj, result|
                obj.should_receive(:print_sprint_header).twice.and_return(true)
                obj.should_receive(:print_sprint_content).twice.and_return(true)
                result.should_receive(:respond_to?).with(:duration).and_return(false)
            }
        end
        it "should only do verbose when dump-header is not available" do
            args = mocked_sprint_args
            args.delete "dump-header"
            check_print_sprint_result(args){|obj, result|
                obj.should_not_receive(:print_sprint_header)
                obj.should_receive(:print_sprint_content).twice.and_return(true)
                result.should_receive(:respond_to?).with(:duration).and_return(false)
            }
        end
        it "should only do dump-header when verbose is not available" do
            args = mocked_sprint_args
            args.delete "verbose"
            check_print_sprint_result(args){|obj, result|
                obj.should_receive(:print_sprint_header).twice.and_return(true)
                obj.should_not_receive(:print_sprint_content)
                result.should_receive(:respond_to?).with(:duration).and_return(false)
            }
        end
    end

    context "print_performance_result" do
        def check_print_performance_result args
            result = mocked_performance
            obj = Blitz::Command::Curl.new
            yield(obj, result)
            obj.send(:print_sprint_result, args, result)
        end

        it "should do print har results" do
            args = mocked_performance_args
            args.delete "screenshot-file"
            args.delete "har-file"
            
            curl = Blitz::Command::Curl.new
            job = Blitz::Curl::Performance.new args
            
            result = mocked_performance
            
            curl.should_receive(:puts).with().exactly(7).times
            curl.should_receive(:print).with("\e[33m  Started \e[0m")
            curl.should_receive(:print).with("\e[33m Duration \e[0m")
            curl.should_receive(:print).with("\e[32m Response \e[0m")
            curl.should_receive(:print).with("\e[35m URL \e[0m")
            curl.should_receive(:print).with("        0 ")
            curl.should_receive(:print).with("        5 ")
            curl.should_receive(:print).with("\e[32m      200 \e[0m")
            curl.should_receive(:print).with(" http://5.184.109.209:8080/").once
            curl.should_receive(:print).with("       10 ")
            curl.should_receive(:print).with("        2 ")
            curl.should_receive(:print).with("\e[31m      404 \e[0m")
            curl.should_receive(:print).with(" http://5.184.109.209:8080/image_wrong.png").once
            curl.should_receive(:puts).with("Load time: \e[32m20\e[0m msec");
            curl.should_receive(:puts).with("Found \e[31m2 problems\e[0m");
            curl.should_receive(:puts).with("  * HTTP errors responses (1 URLs)");
            curl.should_receive(:puts).with("  * Add Expires or Cache-Control headers (1 URLs)");
            
            curl.send(:print_performance_result, job, result)
        end
    end
end
