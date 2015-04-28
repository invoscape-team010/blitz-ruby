class Blitz
class Command
class API < Command # :nodoc:
    attr_accessor :credentials
    attr_accessor :cmd_line_args

    def cmd_init argv
        FileUtils.rm credentials_file rescue nil
        p self.inspect
        p self.cmd_line_args
        @cmd_line_args = argv
        p self.cmd_line_args
        API.client

        msg "You are now ready to blitz!"
        msg "Try blitz help to learn more about the commands."
    end

    def client
      p self.inspect
      p self.cmd_line_args
      p @cmd_line_args.inspect
        get_credentials
        Blitz::Client.new(user, password, host)
    end

    def user
        get_credentials
        @credentials[0]
    end

    def password
        get_credentials
        @credentials[1]
    end

    def host
        ENV['BLITZ_HOST'] || 'www.blitz.io'
    end

    def credentials_file
        ENV['HOME'] + '/.blitz/credentials'
    end

    def get_credentials
      p self.cmd_line_args.inspect
        return if @credentials
        unless @credentials = read_credentials
            @credentials = ask_for_credentials
            save_credentials
        end
        @credentials
    end

    def read_credentials
        File.exists?(credentials_file) and File.read(credentials_file).split("\n")
    end

    def ask_for_credentials
      p self.cmd_line_args.inspect
        if self.cmd_line_args.blank?
          msg "Enter your blitz credentials. You can find this in #{green('Settings/API Key')}."
          print "User-ID: "
          user = ask
          print "API-Key: "
          apik = ask
        else
          user = argv[0]
          apik = argv[1]
        end
        apik2 = Blitz::Client.new(user, apik, host).login['api_key']
        if not apik2
            error "Authentication failed"
            exit 1
        end

        [ user, apik2 ]
    end

    def save_credentials
        write_credentials
    end

    def write_credentials
        FileUtils.mkdir_p(File.dirname(credentials_file))
        File.open(credentials_file, 'w') do |f|
          f.puts self.credentials
        end
        set_credentials_permissions
    end

    def set_credentials_permissions
        FileUtils.chmod 0700, File.dirname(credentials_file)
        FileUtils.chmod 0600, credentials_file
    end

    def self.instance
        @instance ||= API.new
    end

    def self.client
        self.instance.client
    end

    private
    def initialize
    end
end
Api = API
end # Command
end # Blitz
