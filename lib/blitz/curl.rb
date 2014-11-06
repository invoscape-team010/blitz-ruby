require 'blitz/utils'
require 'blitz/curl/performance'

class Blitz
class Curl    
    extend Blitz::Utils
    
    RE_WS = /^\s+/.freeze
    RE_NOT_WS = /^[^\s]+/.freeze
    RE_DQ_STRING = /^"[^"\\\r\n]*(?:\\.[^"\\\r\n]*)*"/.freeze
    RE_SQ_STRING = /^'[^'\\\r\n]*(?:\\.[^'\\\r\n]*)*'/.freeze
    RE_MR_BEGIN = /\[/.freeze
    RE_MR_END = /\]:(\d+)$/.freeze
    RE_MR_WHOLE = /^\[([^\]]+)\]:(\d+)$/.freeze
    RE_PATTERN = /^(\d+)-(\d+):(\d+)$/.freeze
    INVALID_RAMP_PATTERN = 'Invalid ramp pattern'.freeze
    
    def self.parse arguments
        argv = arguments.is_a?(Array) ? arguments : xargv(arguments)
        args = parse_cli argv
        if args['help']
            raise ArgumentError, "help"
        elsif args['har']
            Blitz::Curl::Performance.new args
        elsif not args['pattern']
            Blitz::Curl::Sprint.new args
        else
            Blitz::Curl::Rush.new args
        end
    end
    
    private
    
    
    def self.parse_list list_expr
        # split, make sure comma isn't escaped
        entries = list_expr.split /(?<!\\),/
        # unescape commas
        entries.map {|e| e.gsub "\\,", "," }
    end

    def self.xargv text
        argv = []
        while not text.empty?
            if text.match RE_WS
                text = $'
            elsif text.match RE_DQ_STRING or text.match RE_SQ_STRING or text.match RE_NOT_WS
                text = $'
                argv << strip_quotes($&)
            end
        end
        argv
    end
    
    def self.strip_quotes text
        return text unless text.match RE_DQ_STRING or text.match RE_SQ_STRING
        text[1, (text.size - 2)]
    end
    # returns false if v is not a start of multi-region pattern
    def self.parse_regions argv, k, v, hash
        return false unless v =~ RE_MR_BEGIN

        while not argv.empty? and not v =~ RE_MR_END
            next_v = shift(k, argv)
            v += next_v
        end

        if v =~ RE_MR_WHOLE
            duration = $2.to_i
            intervals = $1.split ','
            regions = []
            total_start = 0
            total_end = 0
            intervals.each do |region_interval|
                region, interval = region_interval.split ':'
                unless region and interval
                    raise ArgumentError, INVALID_RAMP_PATTERN
                end

                interval_start, interval_end = interval.split '-'
                unless interval_start and interval_end
                    raise ArgumentError, INVALID_RAMP_PATTERN
                end

                region_pattern = {
                    'region' => region,
                    'start'  => interval_start.to_i,
                    'end'    => interval_end.to_i
                }
                total_start += region_pattern['start']
                total_end += region_pattern['end']
                regions << region_pattern
            end

            pattern = {
                'iterations' => 1,
                'start' => total_start,
                'end' => total_end,
                'duration' => duration,
                'affinity' => { 'regions' => regions }
            }
            hash['pattern'] ||= { 'iterations' => 1, 'intervals' => [] }
            hash['pattern']['intervals'] << pattern
        else
            raise ArgumentError, INVALID_RAMP_PATTERN
        end
        true
    end
    
    def self.parse_cli argv
        hash = { 'steps' => [] }

        while not argv.empty?
            hash['steps'] << Hash.new
            step = hash['steps'].last

            while not argv.empty?
                break if argv.first[0,1] != '-'

                k = argv.shift
                if [ '-A', '--user-agent' ].member? k
                    step['user-agent'] = shift(k, argv)
                    next
                end

                if [ '-b', '--cookie' ].member? k
                    step['cookies'] ||= []
                    step['cookies'] << shift(k, argv)
                    next
                end

                if [ '-d', '--data' ].member? k
                    step['content'] ||= Hash.new
                    step['content']['data'] ||= []
                    v = shift(k, argv)
                    v = File.read v[1..-1] if v =~ /^@/
                    step['content']['data'] << v
                    next
                end

                if [ '-D', '--dump-header' ].member? k
                    hash['dump-header'] = argv[0]=="-" ?  argv.shift : shift(k, argv)
                    next
                end

                if [ '-e', '--referer'].member? k
                    step['referer'] = shift(k, argv)
                    next
                end

                if [ '-h', '--help' ].member? k
                    hash['help'] = true
                    next
                end

                if [ '-H', '--header' ].member? k
                    step['headers'] ||= []
                    step['headers'].push shift(k, argv)
                    next
                end

                if [ '-p', '--pattern' ].member? k
                    v = shift(k, argv)
                    if self.parse_regions argv, k, v, hash
                        next
                    end
                    ramp = v.split','
                    ramp.each do |vt|
                        pattern = { 'iterations' => 1 }
                        unless RE_PATTERN =~ vt
                            #wrong pattern if this is the first interval or not a number
                            intervals = hash['pattern']['intervals'] rescue nil
                            if intervals.nil? or /^(\d+)$/ !~ vt
                                raise ArgumentError, INVALID_RAMP_PATTERN
                            end
                            last = hash['pattern']['intervals'].last
                            pattern['start'] = last['end']
                            pattern['end'] = last['end']
                            pattern['duration'] = $1.to_i
                        else
                            pattern['start'] = $1.to_i
                            pattern['end'] = $2.to_i
                            pattern['duration'] = $3.to_i
                        end
                        hash['pattern'] ||= { 'iterations' => 1, 'intervals' => [] }
                        hash['pattern']['intervals'] << pattern
                    end
                    next
                end

                if [ '-r', '--region' ].member? k
                    hash['region'] = shift(k, argv)
                    next
                end

                if [ '-k', '--keepalive' ].member? k
                    hash['keepalive'] = true
                    next
                end

                if [ '-s', '--status' ].member? k
                    step['status'] = shift(k, argv).to_i
                    next
                end

                if [ '-T', '--timeout' ].member? k
                    step['timeout'] = shift(k, argv).to_i
                    next
                end

                if [ '-u', '--user' ].member? k
                    step['user'] = shift(k, argv)
                    next
                end

                if [ '-X', '--request' ].member? k
                    step['request'] = shift(k, argv)
                    next
                end
                
                if [ '--har' ].member? k
                    hash['har'] = true
                    next
                end
                
                if [ '-c', '--screenshot' ].member? k
                    if not hash['har']
                      raise ArgumentError,
                            "--screenshot allowed with --har only"
                    else
                      hash['screenshot-file'] = shift(k, argv)
                      next
                    end
                end
                
                if [ '-R', '--dump-har' ].member? k
                    if not hash['har']
                      raise ArgumentError,
                            "--dump-har allowed with --har only"
                    else
                      hash['har-file'] = shift(k, argv)
                      next
                    end
                end
                
                if /-x:c/ =~ k or /--xtract:cookie/ =~ k
                    xname = shift(k, argv)
                    assert_match /^[a-zA-Z_][a-zA-Z_0-9]*$/, xname, 
                        "cookie name must be alphanumeric: #{xname}"

                    step['xtracts'] ||= Hash.new
                    xhash = step['xtracts'][xname] = { 'type' => 'cookie' }
                    next
                end

                if /-v:(\S+)/ =~ k or /--variable:(\S+)/ =~ k 
                    vname = $1
                    vargs = shift(k, argv)

                    assert_match /^[a-zA-Z][a-zA-Z0-9]*$/, vname, 
                        "variable name must be alphanumeric: #{vname}"

                    step['variables'] ||= Hash.new
                    vhash = step['variables'][vname] = Hash.new
                    if vargs.match /^(list)?\[([^\]]+)\]$/
                        vhash['type'] = 'list'
                        vhash['entries'] = parse_list $2
                    elsif vargs.match /^(a|alpha)$/
                        vhash['type'] = 'alpha'
                    elsif vargs.match /^(a|alpha)\[(\d+),(\d+)(,(\d+))??\]$/
                        vhash['type'] = 'alpha'
                        vhash['min'] = $2.to_i
                        vhash['max'] = $3.to_i
                        vhash['count'] = $5 ? $5.to_i : 1000
                    elsif vargs.match /^(n|number)$/
                        vhash['type'] = 'number'
                    elsif vargs.match /^(n|number)\[(-?\d+),(-?\d+)(,(\d+))?\]$/
                        vhash['type'] = 'number'
                        vhash['min'] = $2.to_i
                        vhash['max'] = $3.to_i
                        vhash['count'] = $5 ? $5.to_i : 1000
                    elsif vargs.match /^(u|udid)$/
                        vhash['type'] = 'udid'
                    elsif vargs.match /^(uuid)$/
                        vhash['type'] = 'uuid'
                    else
                        raise ArgumentError, 
                            "Invalid variable args for #{vname}: #{vargs}"
                    end
                    next
                end

                if [ '-V', '--verbose' ].member? k
                    hash['verbose'] = true
                    next
                end

                if [ '-1', '--tlsv1' ].member? k
                    step['ssl'] = 'tlsv1'
                    next
                end

                if [ '-2', '--sslv2' ].member? k
                    step['ssl'] = 'sslv2'
                    next
                end

                if [ '-3', '--sslv3' ].member? k
                    step['ssl'] = 'sslv3'
                    next
                end

                if [ '-o', '--output'].member? k
                    hash['output'] = shift(k, argv)
                    next
                end

                raise ArgumentError, "Unknown option #{k}"
            end

            if step.member? 'content'
                data_size = step['content']['data'].inject(0) { |m, v| m + v.size }
                assert(data_size < 20*1024, "POST content must be < 20KB")
            end

            break if hash['help']

            url = argv.shift
            raise ArgumentError, "no URL specified!" if not url
            step['url'] = url
        end

        if not hash['help']
            if hash['steps'].empty?
                raise ArgumentError, "no URL specified!"
            end
        end

        hash
    end
end
end
