require 'spec_helper'

describe Blitz::Curl do
    describe "parse_cli" do
        context "url" do
            it "should check that the args are not empty" do
                lambda { 
                    Blitz::Curl.parse_cli %w[] 
                }.should raise_error(ArgumentError, /no URL specified!/)
            end

            it "should not check for URL when --help is specified" do
                %w[-h --help].each do |h|
                    hash = Blitz::Curl.parse_cli [h]
                    hash.should include 'help'
                end
            end

            it "should succeed when a URL is given" do
                hash = Blitz::Curl.parse_cli %w[blitz.io]
                hash.should include 'steps'
                hash['steps'].should be_a(Array)
                hash['steps'].size.should == 1
                hash['steps'].first.should include 'url'
                hash['steps'].first['url'].should == 'blitz.io'
            end

            it "should succeed when multiple URLs are given" do
                hash = Blitz::Curl.parse_cli %w[blitz.io docs.blitz.io]
                hash.should include 'steps'
                hash['steps'].should be_a(Array)
                hash['steps'].size.should == 2
                hash['steps'][0].should include 'url'
                hash['steps'][0]['url'].should == 'blitz.io'
                hash['steps'][1].should include 'url'
                hash['steps'][1]['url'].should == 'docs.blitz.io'
            end
        end

        context "user-agent" do
            it "should check that a user-agent is given" do
                lambda { 
                    Blitz::Curl.parse_cli %w[--user-agent] 
                }.should raise_error(MiniTest::Assertion, /missing value/)
            end

            it "should support one user-agent for each step" do
                hash = Blitz::Curl.parse_cli %w[-A foo blitz.io -A bar /faq]
                hash.should include 'steps'
                hash['steps'].size.should == 2
                hash['steps'][0]['user-agent'] == 'foo'
                hash['steps'][1]['user-agent'] == 'bar'
            end
        end

        context "cookie" do
            it "should check that a cookie is given" do
                lambda { Blitz::Curl.parse_cli %w[--cookie] }.should raise_error(MiniTest::Assertion, /missing value/)
            end

            it "should be an array of cookies" do
                hash = Blitz::Curl.parse_cli %w[--cookie foo=bar --cookie hello=world blitz.io]
                hash['steps'].size.should == 1
                step = hash['steps'].first
                step['cookies'].should be_a(Array)
                step['cookies'].should == [ 'foo=bar', 'hello=world' ]
            end

            it "should support one cookie for each step" do
                hash = Blitz::Curl.parse_cli %w[-b foo=bar blitz.io -b hello=world /faq]
                hash.should include 'steps'
                hash['steps'].size.should == 2
                hash['steps'][0]['cookies'] == [ 'foo=bar' ]
                hash['steps'][1]['cookies'] == [ 'hello=world' ]
            end
        end

        context "data" do
            it "should check that a data is given" do
                lambda { Blitz::Curl.parse_cli %w[--data] }.should raise_error(MiniTest::Assertion, /missing value/)
            end

            it "should be an array of data" do
                hash = Blitz::Curl.parse_cli %w[--data foo=bar --data hello=world blitz.io]
                hash['steps'].size.should == 1
                step = hash['steps'].first
                step['content'].should be_a(Hash)
                step['content']['data'].should be_a(Array)
                step['content']['data'].should == [ 'foo=bar', 'hello=world' ]
            end

            it "should support one data for each step" do
                hash = Blitz::Curl.parse_cli %w[-d foo=bar blitz.io -d hello=world /faq]
                hash.should include 'steps'
                hash['steps'].size.should == 2
                hash['steps'][0]['content']['data'] == [ 'foo=bar' ]
                hash['steps'][1]['content']['data'] == [ 'hello=world' ]
            end
        end

        context "referer" do
            it "should check that a referer is given" do
                lambda { Blitz::Curl.parse_cli %w[--referer] }.should raise_error(MiniTest::Assertion, /missing value/)
            end

            it "should support one referer for each step" do
                hash = Blitz::Curl.parse_cli %w[-e foo blitz.io -e bar /faq]
                hash.should include 'steps'
                hash['steps'].size.should == 2
                hash['steps'][0]['referer'] == 'foo'
                hash['steps'][1]['referer'] == 'bar'
            end
        end

        context "headers" do
            it "should check that a header is given" do
                lambda { Blitz::Curl.parse_cli %w[--header] }.should raise_error(MiniTest::Assertion, /missing value/)
            end

            it "should be an array of headers" do
                hash = Blitz::Curl.parse_cli %w[-H foo=bar -H hello=world blitz.io]
                hash['steps'].size.should == 1
                step = hash['steps'].first
                step['headers'].should be_a(Array)
                step['headers'].should == [ 'foo=bar', 'hello=world' ]
            end

            it "should support one header for each step" do
                hash = Blitz::Curl.parse_cli %w[-H foo=bar blitz.io -H hello=world /faq]
                hash.should include 'steps'
                hash['steps'].size.should == 2
                hash['steps'][0]['headers'] == [ 'foo=bar' ]
                hash['steps'][1]['headers'] == [ 'hello=world' ]
            end
        end

        context "variables" do
            it "should raise Assertions::Error if variable name starts with number" do
                command = %w[-p 5-10:10 -v:007 alpha http://example.com]
                lambda { Blitz::Curl.parse_cli command}.should raise_error (MiniTest::Assertion)
            end

            it "should not raise error for variable name is simple string" do
                command = %w[-p 5-10:10 -v:abc alpha http://example.com]
                result = Blitz::Curl.parse_cli command
                result['steps'][0]['variables'].key?('abc').should == true
                result['steps'][0]['variables']['abc']['type'].should == 'alpha'
            end

            it "should accept list variable" do
                command = %w[-p 5-10:10 -v:abc [1,2,3] http://example.com]
                result = Blitz::Curl.parse_cli command
                result['steps'][0]['variables']['abc']['type'].should == 'list'
                result['steps'][0]['variables']['abc']['entries'].should == ["1", "2", "3"]
            end

            context "list" do
                def verify_match expr, entries
                    command = %W[-p 5-10:10 -v:abc #{expr} http://example.com]
                    puts command.inspect
                    result = Blitz::Curl.parse_cli command
                    result['steps'][0]['variables']['abc']['type'].should == 'list'
                    result['steps'][0]['variables']['abc']['entries'].should == entries
                end

                it "should accept list split by comma" do
                    verify_match '[a,2,3]', ["a", "2", "3"]
                end

                it "should accept list with single element" do
                    verify_match '[1]', ["1"]
                end

                it "should accept list variable with escaped comma" do
                    verify_match '[1,\,2]', ["1", ",2"]
                end

                it "should accept list variable with escaped comma entry" do
                    verify_match '[1,\,,2]', ["1", ",", "2"]
                end

                it "should accept list variable with empty string entry" do
                    verify_match '[1,,2]', ["1", "", "2"]
                end

                it "should accept list variable with escaped comma" do
                    verify_match '[1,foo\,bar]', ["1", "foo,bar"]
                end

            end

            it "should raise NameError if variable argument is not expected" do
                command = %w[-p 5-10:10 -v:abc xyz http://example.com]
                lambda { Blitz::Parser.parse command}.should raise_error (NameError)
            end
        end

        context "pattern" do
            it "should check that a pattern is given" do
                lambda { Blitz::Curl.parse_cli %w[--pattern] }.should raise_error(MiniTest::Assertion, /missing value/)
            end

            it "should add the pattern to the hash" do
                hash = Blitz::Curl.parse_cli %w[-p 1-250:60 blitz.io]
                hash['pattern'].should be_a(Hash)
                hash['pattern']['iterations'].should == 1
                hash['pattern']['intervals'].should be_an(Array)
                hash['pattern']['intervals'].size.should == 1
                hash['pattern']['intervals'].first['iterations'].should == 1
                hash['pattern']['intervals'].first['start'].should == 1
                hash['pattern']['intervals'].first['end'].should == 250
                hash['pattern']['intervals'].first['duration'].should == 60
            end

            it "should parse multiple intervals in the pattern" do
                hash = Blitz::Curl.parse_cli %w[-p 1-250:60,500-500:10 blitz.io]
                hash['pattern'].should be_a(Hash)
                hash['pattern']['iterations'].should == 1
                hash['pattern']['intervals'].should be_an(Array)
                hash['pattern']['intervals'].size.should == 2
                hash['pattern']['intervals'].first['iterations'].should == 1
                hash['pattern']['intervals'].first['start'].should == 1
                hash['pattern']['intervals'].first['end'].should == 250
                hash['pattern']['intervals'].first['duration'].should == 60
                hash['pattern']['intervals'].last['iterations'].should == 1
                hash['pattern']['intervals'].last['start'].should == 500
                hash['pattern']['intervals'].last['end'].should == 500
                hash['pattern']['intervals'].last['duration'].should == 10
            end
        end

        context "region" do
            it "should check that a region is given" do
                lambda { Blitz::Curl.parse_cli %w[--region] }.should raise_error(MiniTest::Assertion, /missing value/)
            end

            it "should verify that it's a valid region" do
                [ 'california', 'oregon', 'virginia', 'ireland', 'singapore', 'japan', 'saopaulo' ].each do |r|
                    lambda { Blitz::Curl.parse_cli ['-r', r, 'blitz.io' ] }.should_not raise_error
                end

                lambda { Blitz::Curl.parse_cli %w[-r -a ] }.should raise_error(MiniTest::Assertion, /missing value/)
                lambda { Blitz::Curl.parse_cli %w[-r --data ] }.should raise_error(MiniTest::Assertion, /missing value/)
            end
        end

        context "multiregion" do
            it "should parse with multiple regions" do
                args = "-p [virginia:5-10, japan:3-20]:10 http://example.com".split ' '
                result = Blitz::Curl.parse_cli args
                interval = result['pattern']['intervals'][0]
                interval['duration'].should == 10
                interval['start'].should == 8
                interval['end'].should == 30
                interval['affinity']['regions'][0]['region'].should == 'virginia'
                interval['affinity']['regions'][0]['start'].should == 5
                interval['affinity']['regions'][0]['end'].should == 10
                interval['affinity']['regions'][1]['region'].should == 'japan'
                interval['affinity']['regions'][1]['start'].should == 3
                interval['affinity']['regions'][1]['end'].should == 20
            end

            it "should parse with multiple multi-region intervals" do
                args = "-p [virginia:5-10, japan:3-20]:10 -p [california:10-3, texas:20-5]:20 http://example.com".split ' '
                result = Blitz::Curl.parse_cli args
                interval = result['pattern']['intervals'][0]
                interval['duration'].should == 10
                interval['start'].should == 8
                interval['end'].should == 30
                interval['affinity']['regions'][0]['region'].should == 'virginia'
                interval['affinity']['regions'][0]['start'].should == 5
                interval['affinity']['regions'][0]['end'].should == 10
                interval['affinity']['regions'][1]['region'].should == 'japan'
                interval['affinity']['regions'][1]['start'].should == 3
                interval['affinity']['regions'][1]['end'].should == 20

                interval = result['pattern']['intervals'][1]
                interval['duration'].should == 20
                interval['start'].should == 30
                interval['end'].should == 8
                interval['affinity']['regions'][0]['region'].should == 'california'
                interval['affinity']['regions'][0]['start'].should == 10
                interval['affinity']['regions'][0]['end'].should == 3
                interval['affinity']['regions'][1]['region'].should == 'texas'
                interval['affinity']['regions'][1]['start'].should == 20
                interval['affinity']['regions'][1]['end'].should == 5
            end
        end

        context "status" do
            it "should check that a status is given" do
                lambda { Blitz::Curl.parse_cli %w[--status] }.should raise_error(MiniTest::Assertion, /missing value/)
            end

            it "should support one status for each step" do
                hash = Blitz::Curl.parse_cli %w[-s 302 blitz.io -s 200 /faq]
                hash.should include 'steps'
                hash['steps'].size.should == 2
                hash['steps'][0]['status'] == 302
                hash['steps'][1]['status'] == 200
            end
        end

        context "timeout" do
            it "should check that a timeout is given" do
                lambda { Blitz::Curl.parse_cli %w[--timeout] }.should raise_error(MiniTest::Assertion, /missing value/)
            end

            it "should support one timeout for each step" do
                hash = Blitz::Curl.parse_cli %w[-T 100 blitz.io -T 200 /faq]
                hash.should include 'steps'
                hash['steps'].size.should == 2
                hash['steps'][0]['timeout'] == 100
                hash['steps'][1]['timeout'] == 200
            end
        end

        context "user" do
            it "should check that a user is given" do
                lambda { Blitz::Curl.parse_cli %w[--user] }.should raise_error(MiniTest::Assertion, /missing value/)
            end

            it "should support one user for each step" do
                hash = Blitz::Curl.parse_cli %w[-u foo:bar blitz.io -u hello:world /faq]
                hash.should include 'steps'
                hash['steps'].size.should == 2
                hash['steps'][0]['user'] == 'foo:bar'
                hash['steps'][1]['user'] == 'hello:world'
            end
        end

        context "request" do
            it "should check that a request is given" do
                lambda { Blitz::Curl.parse_cli %w[--request] }.should raise_error(MiniTest::Assertion, /missing value/)
            end

            it "should support one request for each step" do
                hash = Blitz::Curl.parse_cli %w[-X GET blitz.io -X POST /faq]
                hash.should include 'steps'
                hash['steps'].size.should == 2
                hash['steps'][0]['request'] == 'GET'
                hash['steps'][1]['request'] == 'POST'
            end
        end

        context "output" do
            it "should check that a output is given" do
                lambda { Blitz::Curl.parse_cli %w[--output] }.should raise_error(MiniTest::Assertion, /missing value/)
            end

            it "should support export to output file" do
                hash = Blitz::Curl.parse_cli %w[-o test.csv /faq]
                hash['output'].should == 'test.csv'
            end
        end
    end
    
    describe "xargv" do
        context "without quotes" do
            it "should break string into array" do
                array = Blitz::Curl.xargv "-r california www.example.com"
                array.size.should == 3
                array.first.should == "-r"
                array.last.should == "www.example.com"
            end
        end
        
        context "with double quotes" do
            it "should break string into array" do
                array = Blitz::Curl.xargv '-r california -d "a b c d" www.example.com'
                array.size.should == 5
                array.first.should == "-r"
                array.last.should == "www.example.com"
                array[3].should == "a b c d"
            end
        end

        context "with single quotes" do
            it "should break string into array" do
                array = Blitz::Curl.xargv "-r california -d 'a b c d' www.example.com"
                array.size.should == 5
                array.first.should == "-r"
                array.last.should == "www.example.com"
                array[3].should == "a b c d"
            end
        end
    end
end
