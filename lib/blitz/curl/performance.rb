class Blitz
class Curl # :nodoc:
# Use this to run a performance test against your app. The return values include the
# basic har data, the region from which the performance was run along with the
# list of found problems and hints
class Performance
    # Contains the result from a successful performance
    class Result
        # The region from which this sprint was executed
        attr_reader :region
        
        # The analysis hints and warnings (including js exceptions)
        attr_reader :analysis
        
        # The har data (without response bodies)
        # see http://www.softwareishard.com/blog/har-12-spec/ for details
        attr_reader :har
        
        def initialize json # :nodoc:
            result = json['result']
            @region = result['region']
            @analysis = result['analysis']
            @har = result['har']
        end
    end
    
    def queue # :nodoc:
        args.delete 'pattern'
        args.delete :pattern
        args['make_screenshot'] = false
        
        res = Command::API.client.curl_execute args
        raise Error.new(res) if res['error']
        @job_id = res['job_id']
        @region = res['region']
    end
                
    attr_reader :job_id # :nodoc:
    attr_reader :region # :nodoc:
    attr_reader :args # :nodoc:
    
    def initialize args # :nodoc:
        @args = args
    end
    
    def result # :nodoc:
        while true
            sleep 2.0
            
            job = Command::API.client.job_status job_id
            if job['error']
                raise Error
            end

            result = job['result']
            next if job['status'] == 'queued'
            next if job['status'] == 'running' and not result
            
            raise Error if not result
            
            # check possible errors
            error = result['error'] # TODO different error names
            if error
                if error == 'dns'
                    raise Error::DNS.new(result)
                elsif error == 'connect'
                    raise Error::Connect.new(result)
                elsif error == 'timeout'
                    raise Error::Timeout.new(result)
                elsif error == 'parse'
                    raise Error::Parse.new(result)
                elsif error == 'assert'
                    raise Error::Status.new(result)
                else
                    raise Error
                end
            end
            
            return Result.new(job)
        end
    end
    
    def abort # :nodoc:
        Command::API.client.abort_job job_id rescue nil
    end
end
end # Curl
end # Blitz
