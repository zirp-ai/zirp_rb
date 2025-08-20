# frozen_string_literal: true

require_relative "zirp/version"
require_relative "zirp/helpers/message_format_helpers"
require_relative "zirp/helpers/test_results_format_helpers"
require_relative "zirp/helpers/block_builder_helpers"
require "slack-ruby-block-kit"
require "slack-ruby-client"
require "nokogiri"
require "yaml"
require "optparse"
require "json"
require "net/http"
require "uri"
require "mail"

BLOCK_TYPES = %w[section divider actions context file header image input rich_text video].freeze
NOTIFICATION_CHANNELS = %w[slack email twitter linkedin].freeze

# Main module for the Zirp gem
module Zirp
  class << self
    include MessageFormatHelpers
    include TestResultsFormatHelpers
    include BlockBuilderHelpers

    def run(args = ARGV)
      options = parse_options(args)
      
      # Check if the template file is missing
      if options[:template].nil?
        puts "Missing required option: --template"
        exit 1
      end

      # Load the YAML template
      template_data = YAML.load_file(options[:template])
      
      # Load block templates if specified
      block_templates = {}
      if options[:block_templates_file] && File.exist?(options[:block_templates_file])
        block_templates = YAML.load_file(options[:block_templates_file])
        puts "Loaded #{block_templates.keys.size} block templates"
      end
      
      # Process block inheritance if present
      if block_templates.any? && template_data["blocks"]
        template_data["blocks"].map! do |block|
          if block["inherits_from"]
            apply_block_inheritance(block, block_templates)
          else
            block
          end
        end
      end
      
      # Process dynamic blocks if specified
      if options[:dynamic_blocks]
        options[:dynamic_blocks].each do |dynamic_block_config|
          # Load data from file
          data_file = dynamic_block_config[:data_file]
          if File.exist?(data_file)
            data = JSON.parse(File.read(data_file))
            block_type = dynamic_block_config[:block_type]
            template_name = dynamic_block_config[:template_name]
            
            # Get the template for this dynamic block
            block_template = block_templates[template_name]
            if block_template
              # Generate dynamic blocks and add them to the template
              dynamic_blocks = generate_dynamic_blocks(block_type, data, block_template, options[:custom_vars] || {})
              template_data["blocks"] ||= []
              template_data["blocks"].concat(dynamic_blocks)
              puts "Added #{dynamic_blocks.size} dynamic blocks of type '#{block_type}'"
            else
              puts "Warning: Block template '#{template_name}' not found"
            end
          else
            puts "Warning: Data file '#{data_file}' not found"
          end
        end
      end
      
      # Generate release notes if specified
      if options[:generate_release_notes]
        release_notes = generate_release_notes(options[:release_notes_config])
        options[:custom_vars] ||= {}
        options[:custom_vars]["release_notes"] = release_notes
      end

      # Process notifications based on template configuration
      process_notifications(template_data, options)
    end

    def parse_options(args)
      options = {}
      OptionParser.new do |opts|
        opts.banner = "Usage: zirp [options]"

        opts.on("-t", "--template TEMPLATE", "Path to YAML template file") do |t|
          options[:template] = t
        end

        opts.on("--env KEY=VALUE", "Set custom key-value pairs for placeholders", Hash) do |pairs|
          options[:custom_vars] ||= {}
          options[:custom_vars].merge!(pairs)
        end

        opts.on("-a", "--set-auth-in-env", "Use OAuth token from ENV variable") do
          options[:set_auth_in_env] = true
        end

        opts.on("--junit-results JUNIT_PATH", "Path to JUnit XML results file") do |junit|
          options[:junit_results] = junit
        end

        opts.on("--parent-message-id PARENT_MESSAGE_ID", "Specify the parent message for replies") do |parent_message|
          options[:parent_message_id] = parent_message
        end

        opts.on("--set-as-parent-message",
                "Set template to be parent message storing the message timestamp in the ENV variable you specify") do |env_var|
          options[:set_as_parent_message] = env_var
        end

        opts.on("--generate-release-notes", "Generate release notes from git history") do
          options[:generate_release_notes] = true
        end

        opts.on("--release-notes-config CONFIG_FILE", "Path to release notes configuration file") do |config|
          options[:release_notes_config] = config
        end

        opts.on("--video-demo VIDEO_PATH", "Path to video demo file to include") do |video|
          options[:video_demo] = video
        end

        opts.on("--notification-channels CHANNELS", "Comma-separated list of notification channels (slack,email,twitter,linkedin)") do |channels|
          options[:notification_channels] = channels.split(",")
        end
        
        # New options for enhanced block features
        opts.on("--block-templates TEMPLATE_FILE", "Path to block templates YAML file") do |template_file|
          options[:block_templates_file] = template_file
        end
        
        opts.on("--dynamic-blocks DATA_FILE,BLOCK_TYPE,TEMPLATE_NAME", 
                "Generate dynamic blocks from data file using specified template") do |dynamic_config|
          data_file, block_type, template_name = dynamic_config.split(",")
          options[:dynamic_blocks] ||= []
          options[:dynamic_blocks] << {
            data_file: data_file,
            block_type: block_type,
            template_name: template_name
          }
        end
      end.parse(args)
      
      options
    end

    def process_notifications(template_data, options)
      notification_channels = options[:notification_channels] || [template_data["default_channel"] || "slack"]
      
      notification_channels.each do |channel|
        case channel
        when "slack"
          send_slack_notification(template_data, options)
        when "email"
          send_email_notification(template_data, options)
        when "twitter"
          send_twitter_notification(template_data, options)
        when "linkedin"
          send_linkedin_notification(template_data, options)
        else
          puts "Unsupported notification channel: #{channel}"
        end
      end
    end

    def send_slack_notification(template_data, options)
      # Build the Slack message using the template and custom variables
      message = build_slack_message(template_data, options[:custom_vars])

      # Override the OAuth token if the flag is set
      oauth_token = options[:set_auth_in_env] ? ENV["SLACK_OAUTH_TOKEN"] : template_data["slack_oauth_token"]

      # Send the message to Slack
      client = Slack::Web::Client.new(token: oauth_token)

      # If --parent-message-id is set, send the message as a reply to the parent message
      if options[:parent_message_id]
        client.chat_postMessage(channel: template_data["channel"], blocks: message.blocks, attachments: message.attachments,
                              thread_ts: ENV[options[:parent_message_id]])

      # If --set-parent-message is set, store the message timestamp in the specified ENV variable
      elsif options[:set_as_parent_message]
        response = client.chat_postMessage(channel: template_data["channel"], blocks: message.blocks,
                                         attachments: message.attachments)
        ENV[options[:set_as_parent_message]] = response.body["message"]["ts"]

      else
        client.chat_postMessage(channel: template_data["channel"], blocks: message.blocks, attachments: message.attachments)
      end
      
      puts "Slack notification sent successfully!"
    end

    def send_email_notification(template_data, options)
      return unless template_data["email_config"]
      
      email_config = template_data["email_config"]
      
      # Configure email settings
      Mail.defaults do
        delivery_method :smtp, {
          address: email_config["smtp_server"],
          port: email_config["smtp_port"],
          user_name: email_config["username"],
          password: email_config["password"],
          authentication: 'plain',
          enable_starttls_auto: true
        }
      end

      # Create and send email
      mail = Mail.new do
        from     email_config["from"]
        to       email_config["recipients"]
        subject  email_config["subject"]
        
        # Convert blocks to HTML for email
        html_part do
          content_type 'text/html; charset=UTF-8'
          body generate_html_from_blocks(template_data["blocks"], options[:custom_vars])
        end
        
        # Add attachments if specified
        if options[:video_demo] && File.exist?(options[:video_demo])
          add_file filename: File.basename(options[:video_demo]), content: File.read(options[:video_demo])
        end
      end
      
      mail.deliver!
      puts "Email notification sent successfully!"
    end

    def send_twitter_notification(template_data, options)
      return unless template_data["twitter_config"]
      
      twitter_config = template_data["twitter_config"]
      
      # This is a placeholder for Twitter API integration
      # In a real implementation, you would use a Twitter API client
      puts "Twitter notification would be sent with the following content:"
      puts generate_text_from_blocks(template_data["blocks"], options[:custom_vars])
      puts "Twitter integration requires API credentials to be configured."
    end

    def send_linkedin_notification(template_data, options)
      return unless template_data["linkedin_config"]
      
      linkedin_config = template_data["linkedin_config"]
      
      # This is a placeholder for LinkedIn API integration
      # In a real implementation, you would use a LinkedIn API client
      puts "LinkedIn notification would be sent with the following content:"
      puts generate_text_from_blocks(template_data["blocks"], options[:custom_vars])
      puts "LinkedIn integration requires API credentials to be configured."
    end

    def build_slack_message(template_data, custom_vars)
      message = Slack::BlockKit::Message.new

      # Add video demo if specified
      if custom_vars && custom_vars["video_demo"]
        video_block = {
          "type" => "video",
          "title" => { "text" => "Product Demo" },
          "video_url" => custom_vars["video_demo"],
          "thumbnail_url" => custom_vars["video_thumbnail"] || custom_vars["video_demo"].gsub(/\.\w+$/, ".jpg")
        }
        message.blocks << build_block(video_block, custom_vars)
      end

      # Build blocks
      if template_data["blocks"]
        # Process any block references
        processed_blocks = template_data["blocks"].map do |block_data|
          # If this is a block reference, replace it with the actual block
          if block_data["use_template"] && template_data["block_templates"] && template_data["block_templates"][block_data["use_template"]]
            template = template_data["block_templates"][block_data["use_template"]]
            # Apply any overrides from the reference
            overrides = block_data.reject { |k, _| k == "use_template" }
            apply_overrides(template.dup, overrides)
          else
            block_data
          end
        end
        
        blocks = processed_blocks.map { |block_data| build_block(block_data, custom_vars) }
        message.blocks(blocks)
      end

      # Build attachments
      if template_data["attachments"]
        attachments = template_data["attachments"].map { |attachment_data| build_attachment(attachment_data, custom_vars) }
        message.attachments(attachments)
      end
      
      message
    end

    def build_block(block_data, custom_vars)
      raise "Unsupported block type: #{block_data["type"]}" unless BLOCK_TYPES.include?(block_data["type"])

      MessageFormatHelpers.send("generate_#{block_data["type"]}_block", block_data, custom_vars)
    end

    def generate_release_notes(config_file)
      return "No release notes configuration provided" unless config_file && File.exist?(config_file)
      
      config = YAML.load_file(config_file)
      
      # Get git log between specified tags/commits
      from_ref = config["from_ref"] || "HEAD~10"
      to_ref = config["to_ref"] || "HEAD"
      
      git_log = `git log #{from_ref}..#{to_ref} --pretty=format:"%h %s" --no-merges`
      
      # Format the release notes
      notes = "# Release Notes\n\n"
      notes += "## Changes from #{from_ref} to #{to_ref}\n\n"
      
      # Group by categories if specified
      if config["categories"]
        categorized_commits = {}
        config["categories"].each { |cat| categorized_commits[cat] = [] }
        categorized_commits["Other"] = []
        
        git_log.each_line do |line|
          hash, message = line.split(" ", 2)
          category = "Other"
          
          config["categories"].each do |cat|
            if message =~ /#{cat}/i
              category = cat
              break
            end
          end
          
          categorized_commits[category] << "- #{message.strip} (#{hash})"
        end
        
        categorized_commits.each do |category, commits|
          next if commits.empty?
          notes += "### #{category}\n\n"
          notes += commits.join("\n")
          notes += "\n\n"
        end
      else
        # Simple list of all commits
        git_log.each_line do |line|
          hash, message = line.split(" ", 2)
          notes += "- #{message.strip} (#{hash})\n"
        end
      end
      
      notes
    end

    def generate_html_from_blocks(blocks, custom_vars)
      html = "<html><body>"
      
      blocks.each do |block|
        case block["type"]
        when "header"
          text = process_placeholders(block["text"], custom_vars)
          html += "<h1>#{text}</h1>"
        when "section"
          text = process_placeholders(block["text"]["text"], custom_vars)
          html += "<div>#{text}</div>"
        when "image"
          url = process_placeholders(block["image_url"], custom_vars)
          alt = process_placeholders(block["alt_text"], custom_vars)
          html += "<img src='#{url}' alt='#{alt}' style='max-width:100%;'>"
        when "video"
          url = process_placeholders(block["video_url"], custom_vars)
          html += "<video controls style='max-width:100%;'><source src='#{url}' type='video/mp4'>Your browser does not support the video tag.</video>"
        end
      end
      
      html += "</body></html>"
      html
    end

    def generate_text_from_blocks(blocks, custom_vars)
      text = ""
      
      blocks.each do |block|
        case block["type"]
        when "header"
          text += "# #{process_placeholders(block["text"], custom_vars)}\n\n"
        when "section"
          text += "#{process_placeholders(block["text"]["text"], custom_vars)}\n\n"
        end
      end
      
      text
    end
  end
end
