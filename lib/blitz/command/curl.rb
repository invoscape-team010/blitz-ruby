class Blitz
class Command
class Curl < Command # :nodoc:
    def cmd_help argv
        help
    end

    def cmd_run argv
        begin
            test = Blitz::Curl.parse argv
        rescue "help"
            return help
        end
        if test.class == Blitz::Curl::Sprint
            sprint test
        elsif test.class == Blitz::Curl::Rush
            rush test
        else
            performance test
        end
    end
    
    alias_method :cmd_default, :cmd_run

    private
    def authorize_error e
        base_url = "#{e.scheme}://#{e.host}:#{e.port}"
        puts
        error "You haven't verified that you are the devops dude for #{e.host}. Make"
        error "sure the following URL is reachable and returns the string '42'."
        error ""
        error "#{base_url}/#{e.uuid}"
        error ""
        if e.checks
            error "We tried checking the following URLs and got this"
            error ""
            e.checks.each do |check|
                bytes = ''
                if check['bytes']
                    bytes = '| ' + check['bytes']
                end
                error "#{bold(red(check['code']))} | #{cyan(check['url'])} #{bytes}"
            end
            error ''
        end
        error "If your app is RESTfully built with sinatra or rails, simply add this route:"
        error ""
        error "get '/#{cyan(e.uuid)}' do"
        error "    '42'"
        error "end"
        error ""
        error "Once this is done, you can blitz #{cyan(e.host)} all you want."
        puts
    end

    def sprint job
        begin
            job.queue
            error "sprinting from #{yellow(job.region)}"
            result = job.result
            print_sprint_result job.args, result
        rescue ::Blitz::Curl::Error::Authorize => e
            authorize_error e
        rescue ::Blitz::Curl::Error::Step => e
            error "#{red(e.message)} in step #{e.step}"
            puts
            print_sprint_result job.args, e
        rescue ::Blitz::Curl::Error::Region => e
            error "#{red(e.message)}"
        rescue ::Blitz::Curl::Error => e
            error red(e.message)
        end
    end
    
    def pretty_print_duration duration
        rtt = duration
		if rtt < 1.0
			rtt = (rtt * 1000).floor.to_s + ' ms';
		else
			rtt = ("%.2f" % rtt) + ' sec';
		end
    end
    
    def print_sprint_content content
        if not content.empty?
            if /^[[:print:]]+$/ =~ content
                puts content
            else
                Hexdump.dump(content, :width => 16)
            end
            puts
        end
    end
    
    def print_sprint_header obj, path, symbol, mode
        if path == "-"
            puts symbol + obj.line
            obj.headers.each_pair { |k, v| puts "#{symbol}#{k}: #{v}\r\n" }
            puts
        else
            begin
                File.open(path, mode) do |myfile|
                    myfile.puts ""
                    myfile.puts obj.line
                    obj.headers.each_pair { |k, v| myfile.puts("#{k}: #{v}") }    
                end
            rescue Exception => e
                msg "#{red(e.message)}"
            end
        end
    end

    def print_sprint_result args, result
        if result.respond_to? :duration
            rtt = pretty_print_duration result.duration
            msg "Transaction time #{green(rtt)}"
            puts
        end
        
        result.steps.each do |step|
            req, res = step.request, step.response
            dump_header = args['dump-header']
            verbose  = args['verbose']
            if dump_header and verbose
                print_sprint_header req, dump_header, "> ", 'w'
                print_sprint_content req.content
                if res
                    print_sprint_header res, dump_header, "< ", 'a'
                    print_sprint_content res.content
                end
            elsif dump_header.nil? and verbose
                print_sprint_content req.content
                print_sprint_content res.content if res
            elsif dump_header and verbose.nil?
                print_sprint_header req, dump_header, "> ", 'w'
                print_sprint_header res, dump_header, "< ", 'a' if res
            else
                puts "> " + req.method + ' ' + req.url
                if res
                    text = "< " + res.status.to_s + ' ' + res.message
                    if step.duration
                        text << ' in ' + green(pretty_print_duration(step.duration))
                    end
                    puts text
                end
                puts
            end
        end
    end

    def performance job
        begin
            job.queue
            error "performance from #{yellow(job.region)}"
            result = job.result
            print_performance_result job.args, result
        rescue ::Blitz::Curl::Error::Authorize => e
            authorize_error e
        # QUESTION shall we ::Blitz::Curl::Error::Step ?
            error "#{red(e.message)}"
        rescue ::Blitz::Curl::Error => e
            error red(e.message)
        end
    end
    
    def to_msec date_str
        DateTime.parse(date_str).strftime('%Q').to_i
    end

    def print_performance_result args, result
        # HAR data
        puts
        print "%9s " % "Started"
        print "%9s " % "Duration"
        print "%9s " % "Response"
        print "%4s " % "URL"
        puts
        
        log = result.har['log']
        entries = log['entries']
        started = to_msec entries[0]['startedDateTime']
        entries.each do |entry|
            code = entry['response']['status'].to_i
            next if code == 0
       
            print "%9s " % "#{to_msec(entry['startedDateTime']) - started}"
            print "%9s " % "#{entry['time']}"
            print code >= 300 ? code >= 400 ? red("%9s " % code) : yellow("%9s " % code) : green("%9s " % code)
            print " #{entry['request']['url']}"
            puts
        end

        puts
        puts "Load time: #{green(result.har['log']['pages'][0]['pageTimings']['onLoad'].to_s)} msec"
        puts
        
        # Analysis data
        print_problems result, 1
        print_problems result, 2
        print_problems result, 3
    end
    
    def print_problems result, priority
        return if priority > 3 or priority < 1

        type_to_label = {
            "js_errors" => "Javascript errors",
            "http_errors_responses" => "HTTP errors responses",
            "add_expires_cache_control" => "Add Expires or Cache-Control headers",
            "redirects" => "Avoid Redirects",
            "compress_gzip" => "Compress components with gzip",
            "minify" => "Minify JavaScript",
            "http_requests" => "Make fewer HTTP requests",
            "use_cdn" => "Use a Content Delivery Network",
            "reduce_dns_lookups" => "Reduce DNS Lookups",
            "remove_duplicates" => "Remove Duplicate Scripts",
            "reduce_cookie_size" => "Reduce cookies size",
            "cookie_free_domains" => "Use cookies-free domains"
        }
        
        priority_to_message = {
            1 => ["Found #{red('%d problems')}",
                "Found #{red('one problem')}"],
            2 => ["Found #{yellow('%d warnings')}",
                "Found #{yellow('one warning')}"],
            3 => ["Consider also #{blue('the following %d tips')}",
                "Consider also #{blue('the following tip')}"]
        }
        
        problems = result.analysis.select { |problem| problem['priority'] == priority and problem['entries'].count > 0 }
        if problems.count > 0
            puts priority_to_message[priority][problems.count != 1 ? 0 : 1] % problems.count
            problems.each do |problem|
                desc = type_to_label.fetch(problem['type'], problem['type'])
                puts "  * #{desc} (#{problem['entries'].count} URLs)"
            end
            puts
        end
    end 

    def rush job
        continue = true
        last_index = nil
        signals = Signal.list.keys & [ 'INT', 'STOP', 'HUP' ]
        begin
            signals.each do |s| 
                trap(s) { continue = false }
            end
            job.queue
            msg "rushing from #{yellow(job.region)}..."
            puts

            if job.args.member?('output')
                file = CSV.open(job.args['output'] || 'blitz.csv', 'w')
            end

            job.result do |result|
                if file
                    csv_rush_result file, result, last_index
                else
                    print_rush_result job.args, result, last_index
                end

                if not result.timeline.empty?
                    last_index = result.timeline.size
                end
                sleep 2.0 if not continue
                continue
            end
            puts
            msg "[#{red('aborted')}]" if not continue
        rescue ::Blitz::Curl::Error::Authorize => e
            authorize_error e
        rescue ::Blitz::Curl::Error::Region => e
            error "#{yellow(e.region)}: #{red(e.message)}"
        rescue ::Blitz::Curl::Error => e
            error red(e.message)
        ensure
            file.close if file
        end
    end

    def print_rush_result args, result, last_index
        if last_index.nil?
            print yellow("%6s " % "Time")
            print "%6s " % "Users"
            print green("%8s " % "Response")
            print green("%8s " % "Hits")
            print magenta("%8s " % "Timeouts")
            print red("%8s " % "Errors")
            print green("%8s " % "Hits/s")
            print "%s" % "Mbps"
            puts
        end

        if last_index and result.timeline.size == last_index
            return
        end

        last = result.timeline[-2]
        curr = result.timeline[-1]
        print yellow("%5.1fs " % curr.timestamp)
        print "%6d " % curr.volume
        print green("%7.3fs " % curr.duration)
        print green("%8d " % curr.hits)
        print magenta("%8d " % curr.timeouts)
        print red("%8d " % curr.errors)

        if last
            elapsed = curr.timestamp - last.timestamp
            mbps = ((curr.txbytes + curr.rxbytes) - (last.txbytes + last.rxbytes))/elapsed/1024.0/1024.0
            htps = (curr.hits - last.hits)/elapsed
            print green(" %7.2f " % htps)
            print "%.2f" % mbps
        end

        print "\n"
    end

    def csv_rush_result file, result, last_index
        if last_index.nil?
            file << ["Time", "Users", "Response", "Hits", "Timeouts", "Errors", "Hits/s", "Mbps"]
        end

        if last_index and result.timeline.size == last_index
            return
        end

        last = result.timeline[-2]
        curr = result.timeline[-1]
        arr  = [curr.timestamp, curr.volume, curr.duration, curr.hits, curr.timeouts, curr.errors ]

        if last
            elapsed = curr.timestamp - last.timestamp
            mbps = ((curr.txbytes + curr.rxbytes) - (last.txbytes + last.rxbytes))/elapsed/1024.0/1024.0
            htps = (curr.hits - last.hits)/elapsed
            arr << htps
            arr << mbps
        end

        file << arr
        file.flush
    end

    def help
        helps = [
            { :short => '-A', :long => '--user-agent', :value => '<string>', :help => 'User-Agent to send to server' },
            { :short => '-b', :long => '--cookie', :value => 'name=<string>', :help => 'Cookie to send to the server (multiple)' },
            { :short => '-d', :long => '--data', :value => '<string>', :help => 'Data to send in a PUT or POST request' },
            { :short => '-D', :long => '--dump-header', :value => '<file>', :help => 'Print the request/response headers' },
            { :short => '-e', :long => '--referer', :value => '<string>', :help => 'Referer URL' },
            { :short => '-h', :long => '--help', :value => '', :help => 'Help on command line options' },
            { :short => '-H', :long => '--header', :value => '<string>', :help => 'Custom header to pass to server' },
            { :short => '-p', :long => '--pattern', :value => '<s>-<e>:<d>', :help => 'Ramp from s to e concurrent requests in d secs' },
            { :short => '-r', :long => '--region', :value => '<string>', :help => 'california|oregon|virginia|singapore|ireland|japan' },
            { :short => '-s', :long => '--status', :value => '<number>', :help => 'Assert on the HTTP response status code' },
            { :short => '-T', :long => '--timeout', :value => '<ms>', :help => 'Wait time for both connect and responses' },
            { :short => '-u', :long => '--user', :value => '<user[:pass]>', :help => 'User and password for authentication' },
            { :short => '-X', :long => '--request', :value => '<string>', :help => 'Request method to use (GET, HEAD, PUT, etc.)' },
            { :short => '-v', :long => '--variable', :value => '<string>', :help => 'Define a variable to use' },
            { :short => '-V', :long => '--verbose', :value => '', :help => 'Print the request/response headers' },
            { :short => '-o', :long => '--output', :value => '<filename>', :help => 'Output to file (CSV)' },
            { :short => '-1', :long => '--tlsv1', :value => '', :help => 'Use TLSv1 (SSL)' },
            { :short => '-2', :long => '--sslv2', :value => '', :help => 'Use SSLv2 (SSL)' },
            { :short => '-3', :long => '--sslv3', :value => '', :help => 'Use SSL (SSLv3)' },
            { :long => '--har', :value => '', :help => 'Run performance test' }
        ]

        max_long_size = helps.inject(0) { |memo, obj| [ obj[:long].size, memo ].max }
        max_value_size = helps.inject(0) { |memo, obj| [ obj[:value].size, memo ].max }
        puts
        msg "Usage: blitz curl <options> <url>"
        puts
        helps.each do |h|
            msg "%-*s %*s %-*s %s" % [max_long_size, h[:long], 2, h[:short], max_value_size, h[:value], h[:help]]
        end
        puts
    end

end # Curl
end # Command
end # Blitz
