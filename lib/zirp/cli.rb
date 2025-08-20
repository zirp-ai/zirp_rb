require 'optparse'
require 'json'

module Zirp
  class CLI
    attr_reader :options, :command, :args
    
    def initialize(args = ARGV)
      @args = args
      @options = {}
      parse_options
    end
    
    def run
      case command
      when 'content'
        handle_content_command
      when 'platform'
        handle_platform_command
      when 'version'
        puts "Zirp Ruby Client v#{Zirp::VERSION}"
      when 'help'
        puts parser
      else
        puts "Unknown command: #{command}"
        puts parser
        exit 1
      end
    rescue Zirp::Errors::ZirpError => e
      puts "Error: #{e.message}"
      exit 1
    end
    
    private
    
    def parse_options
      @parser = OptionParser.new do |opts|
        opts.banner = "Usage: zirp [options] [command]"
        
        opts.separator ""
        opts.separator "Commands:"
        opts.separator "  content list                           List all contents"
        opts.separator "  content get ID                         Get content by ID"
        opts.separator "  content create --title TITLE --body BODY  Create new content"
        opts.separator "  content update ID --title TITLE --body BODY  Update content"
        opts.separator "  content delete ID                      Delete content"
        opts.separator "  content generate ID --prompt PROMPT    Generate content using LLM"
        opts.separator "  content preview ID                     Preview content for all platforms"
        opts.separator "  content publish ID --platforms IDS     Publish content to platforms"
        opts.separator ""
        opts.separator "  platform list                          List all platforms"
        opts.separator "  platform get ID                        Get platform by ID"
        opts.separator "  platform create --name NAME --type TYPE  Create new platform"
        opts.separator "  platform update ID --name NAME         Update platform"
        opts.separator "  platform delete ID                     Delete platform"
        opts.separator "  platform types                         List available platform types"
        opts.separator ""
        opts.separator "  version                                Show version"
        opts.separator "  help                                   Show this help"
        
        opts.separator ""
        opts.separator "Options:"
        
        opts.on("--api-key KEY", "API key for authentication") do |key|
          options[:api_key] = key
        end
        
        opts.on("--api-endpoint URL", "API endpoint URL") do |url|
          options[:api_endpoint] = url
        end
        
        opts.on("--title TITLE", "Content title") do |title|
          options[:title] = title
        end
        
        opts.on("--body BODY", "Content body") do |body|
          options[:body] = body
        end
        
        opts.on("--name NAME", "Platform name") do |name|
          options[:name] = name
        end
        
        opts.on("--type TYPE", "Platform type") do |type|
          options[:type] = type
        end
        
        opts.on("--config CONFIG", "Platform configuration (JSON string)") do |config|
          options[:config] = JSON.parse(config)
        end
        
        opts.on("--prompt PROMPT", "Prompt template for content generation") do |prompt|
          options[:prompt] = prompt
        end
        
        opts.on("--context CONTEXT", "Context for content generation (JSON string)") do |context|
          options[:context] = JSON.parse(context)
        end
        
        opts.on("--platforms IDS", "Comma-separated platform IDs") do |ids|
          options[:platform_ids] = ids.split(',').map(&:strip)
        end
        
        opts.on("--format FORMAT", "Output format (json or pretty)") do |format|
          options[:format] = format
        end
        
        opts.on("-h", "--help", "Show this help") do
          puts opts
          exit
        end
      end
      
      @parser.parse!(args)
      @command = args.shift || 'help'
    end
    
    def parser
      @parser
    end
    
    def client
      @client ||= begin
        Zirp.configure do |config|
          config.api_key = options[:api_key] if options[:api_key]
          config.api_endpoint = options[:api_endpoint] if options[:api_endpoint]
        end
        Zirp.client
      end
    end
    
    def handle_content_command
      subcommand = args.shift || 'list'
      
      case subcommand
      when 'list'
        output client.list_contents
      when 'get'
        id = args.shift
        raise Zirp::Errors::ZirpError, "Content ID is required" unless id
        output client.get_content(id)
      when 'create'
        validate_options(:title, :body)
        output client.create_content(
          title: options[:title],
          body: options[:body]
        )
      when 'update'
        id = args.shift
        raise Zirp::Errors::ZirpError, "Content ID is required" unless id
        params = {}
        params[:title] = options[:title] if options[:title]
        params[:body] = options[:body] if options[:body]
        output client.update_content(id, params)
      when 'delete'
        id = args.shift
        raise Zirp::Errors::ZirpError, "Content ID is required" unless id
        output client.delete_content(id)
      when 'generate'
        id = args.shift
        raise Zirp::Errors::ZirpError, "Content ID is required" unless id
        validate_options(:prompt)
        output client.generate_content(id, options[:prompt], options[:context] || {})
      when 'preview'
        id = args.shift
        raise Zirp::Errors::ZirpError, "Content ID is required" unless id
        output client.preview_content(id)
      when 'publish'
        id = args.shift
        raise Zirp::Errors::ZirpError, "Content ID is required" unless id
        validate_options(:platform_ids)
        output client.publish_content(id, options[:platform_ids])
      else
        puts "Unknown content subcommand: #{subcommand}"
        puts parser
        exit 1
      end
    end
    
    def handle_platform_command
      subcommand = args.shift || 'list'
      
      case subcommand
      when 'list'
        output client.list_platforms
      when 'get'
        id = args.shift
        raise Zirp::Errors::ZirpError, "Platform ID is required" unless id
        output client.get_platform(id)
      when 'create'
        validate_options(:name, :type)
        params = {
          name: options[:name],
          platform_type: options[:type]
        }
        params[:config] = options[:config] if options[:config]
        output client.create_platform(params)
      when 'update'
        id = args.shift
        raise Zirp::Errors::ZirpError, "Platform ID is required" unless id
        params = {}
        params[:name] = options[:name] if options[:name]
        params[:platform_type] = options[:type] if options[:type]
        params[:config] = options[:config] if options[:config]
        output client.update_platform(id, params)
      when 'delete'
        id = args.shift
        raise Zirp::Errors::ZirpError, "Platform ID is required" unless id
        output client.delete_platform(id)
      when 'validate'
        id = args.shift
        raise Zirp::Errors::ZirpError, "Platform ID is required" unless id
        output client.validate_platform_credentials(id)
      when 'types'
        output client.platform_types
      when 'capabilities'
        id = args.shift
        raise Zirp::Errors::ZirpError, "Platform ID is required" unless id
        output client.platform_capabilities(id)
      else
        puts "Unknown platform subcommand: #{subcommand}"
        puts parser
        exit 1
      end
    end
    
    def validate_options(*required_options)
      missing = required_options.select { |opt| options[opt].nil? }
      if missing.any?
        raise Zirp::Errors::ZirpError, "Missing required options: #{missing.join(', ')}"
      end
    end
    
    def output(data)
      case options[:format]
      when 'json'
        puts JSON.pretty_generate(data)
      else
        pp data
      end
    end
  end
end
