# frozen_string_literal: true

RSpec.describe Zirp do
  it "has a version number" do
    expect(Zirp::VERSION).not_to be nil
  end

  describe ".parse_options" do
    it "parses template option" do
      options = Zirp.parse_options(["--template", "path/to/template.yml"])
      expect(options[:template]).to eq("path/to/template.yml")
    end

    it "parses custom environment variables" do
      options = Zirp.parse_options(["--env", "KEY=value"])
      expect(options[:custom_vars]).to eq({"KEY" => "value"})
    end

    it "parses notification channels" do
      options = Zirp.parse_options(["--notification-channels", "slack,email"])
      expect(options[:notification_channels]).to eq(["slack", "email"])
    end

    it "parses release notes generation flag" do
      options = Zirp.parse_options(["--generate-release-notes"])
      expect(options[:generate_release_notes]).to be true
    end

    it "parses video demo path" do
      options = Zirp.parse_options(["--video-demo", "path/to/video.mp4"])
      expect(options[:video_demo]).to eq("path/to/video.mp4")
    end
    
    it "parses block templates file path" do
      options = Zirp.parse_options(["--block-templates", "path/to/block_templates.yml"])
      expect(options[:block_templates_file]).to eq("path/to/block_templates.yml")
    end
    
    it "parses dynamic blocks configuration" do
      options = Zirp.parse_options(["--dynamic-blocks", "data.json,section,feature_template"])
      expect(options[:dynamic_blocks]).to be_an(Array)
      expect(options[:dynamic_blocks].first[:data_file]).to eq("data.json")
      expect(options[:dynamic_blocks].first[:block_type]).to eq("section")
      expect(options[:dynamic_blocks].first[:template_name]).to eq("feature_template")
    end
    
    it "supports multiple dynamic blocks configurations" do
      options = Zirp.parse_options([
        "--dynamic-blocks", "data1.json,section,template1",
        "--dynamic-blocks", "data2.json,header,template2"
      ])
      expect(options[:dynamic_blocks].size).to eq(2)
      expect(options[:dynamic_blocks][0][:data_file]).to eq("data1.json")
      expect(options[:dynamic_blocks][1][:data_file]).to eq("data2.json")
    end
  end

  describe ".generate_release_notes" do
    it "returns a message when no config file is provided" do
      expect(Zirp.generate_release_notes(nil)).to eq("No release notes configuration provided")
    end
  end

  describe ".generate_html_from_blocks" do
    it "converts header blocks to HTML" do
      blocks = [
        { "type" => "header", "text" => "Test Header" }
      ]
      html = Zirp.generate_html_from_blocks(blocks, {})
      expect(html).to include("<h1>Test Header</h1>")
    end

    it "converts section blocks to HTML" do
      blocks = [
        { "type" => "section", "text" => { "text" => "Test Section", "type" => "mrkdwn" } }
      ]
      html = Zirp.generate_html_from_blocks(blocks, {})
      expect(html).to include("<div>Test Section</div>")
    end
  end

  describe ".generate_text_from_blocks" do
    it "converts header blocks to text" do
      blocks = [
        { "type" => "header", "text" => "Test Header" }
      ]
      text = Zirp.generate_text_from_blocks(blocks, {})
      expect(text).to include("# Test Header")
    end

    it "converts section blocks to text" do
      blocks = [
        { "type" => "section", "text" => { "text" => "Test Section", "type" => "mrkdwn" } }
      ]
      text = Zirp.generate_text_from_blocks(blocks, {})
      expect(text).to include("Test Section")
    end
  end
  
  describe "block builder functionality" do
    describe "#apply_block_inheritance" do
      it "applies inheritance to blocks" do
        block_templates = {
          "base_block" => {
            "type" => "section",
            "text" => {
              "type" => "mrkdwn",
              "text" => "Base text"
            }
          }
        }
        
        block = {
          "inherits_from" => "base_block",
          "text" => {
            "text" => "Override text"
          }
        }
        
        result = Zirp.apply_block_inheritance(block, block_templates)
        
        expect(result["type"]).to eq("section")
        expect(result["text"]["type"]).to eq("mrkdwn")
        expect(result["text"]["text"]).to eq("Override text")
      end
    end
    
    describe "#generate_dynamic_blocks" do
      it "generates blocks from data" do
        data = [
          { "name" => "Feature 1", "description" => "Description 1" },
          { "name" => "Feature 2", "description" => "Description 2" }
        ]
        
        template = {
          "text" => {
            "type" => "mrkdwn",
            "text" => "*{{item.name}}*: {{item.description}}"
          }
        }
        
        blocks = Zirp.generate_dynamic_blocks("section", data, template)
        
        expect(blocks.size).to eq(2)
        expect(blocks[0]["type"]).to eq("section")
        expect(blocks[0]["text"]["text"]).to eq("*Feature 1*: Description 1")
        expect(blocks[1]["text"]["text"]).to eq("*Feature 2*: Description 2")
      end
    end
    
    describe "#build_slack_message" do
      it "processes block templates in the message" do
        template_data = {
          "block_templates" => {
            "feature_block" => {
              "type" => "section",
              "text" => {
                "type" => "mrkdwn",
                "text" => "Template text"
              }
            }
          },
          "blocks" => [
            {
              "use_template" => "feature_block",
              "text" => {
                "text" => "Override text"
              }
            }
          ]
        }
        
        message = Zirp.build_slack_message(template_data, {})
        
        # Extract the block from the message for testing
        block = message.blocks.first
        expect(block.type).to eq("section")
        expect(block.text.text).to eq("Override text")
      end
    end
  end
end
