# frozen_string_literal: true

RSpec.describe BlockBuilderHelpers do
  # Create a test class that includes the module
  let(:test_class) do
    Class.new do
      include BlockBuilderHelpers
    end
  end

  let(:instance) { test_class.new }

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
      
      blocks = instance.generate_dynamic_blocks("section", data, template)
      
      expect(blocks.size).to eq(2)
      expect(blocks[0]["type"]).to eq("section")
      expect(blocks[0]["text"]["text"]).to eq("*Feature 1*: Description 1")
      expect(blocks[1]["text"]["text"]).to eq("*Feature 2*: Description 2")
    end
    
    it "applies custom variables" do
      data = [{ "name" => "Feature", "description" => "Description" }]
      template = { "text" => "{{item.name}} - {{version}}" }
      custom_vars = { "version" => "1.0.0" }
      
      blocks = instance.generate_dynamic_blocks("header", data, template, custom_vars)
      
      expect(blocks[0]["text"]).to eq("Feature - 1.0.0")
    end
  end
  
  describe "#apply_block_template" do
    it "applies a template from the library" do
      template_library = {
        "feature_section" => {
          "type" => "section",
          "text" => {
            "type" => "mrkdwn",
            "text" => "Default text"
          }
        }
      }
      
      block = instance.apply_block_template("feature_section", template_library)
      
      expect(block["type"]).to eq("section")
      expect(block["text"]["text"]).to eq("Default text")
    end
    
    it "applies overrides to the template" do
      template_library = {
        "feature_section" => {
          "type" => "section",
          "text" => {
            "type" => "mrkdwn",
            "text" => "Default text"
          },
          "accessory" => {
            "type" => "image",
            "image_url" => "default.png"
          }
        }
      }
      
      overrides = {
        "text" => {
          "text" => "Override text"
        }
      }
      
      block = instance.apply_block_template("feature_section", template_library, overrides)
      
      expect(block["text"]["text"]).to eq("Override text")
      expect(block["accessory"]["image_url"]).to eq("default.png") # Not overridden
    end
    
    it "processes placeholders in the template" do
      template_library = {
        "header" => {
          "type" => "header",
          "text" => "Release {{version}}"
        }
      }
      
      custom_vars = { "version" => "1.2.0" }
      
      block = instance.apply_block_template("header", template_library, {}, custom_vars)
      
      expect(block["text"]).to eq("Release 1.2.0")
    end
    
    it "raises an error if template is not found" do
      expect {
        instance.apply_block_template("non_existent", {})
      }.to raise_error(/Template 'non_existent' not found/)
    end
  end
  
  describe "#apply_block_inheritance" do
    it "inherits properties from parent block" do
      template_library = {
        "base_section" => {
          "type" => "section",
          "text" => {
            "type" => "mrkdwn",
            "text" => "Base text"
          },
          "accessory" => {
            "type" => "image",
            "image_url" => "base.png"
          }
        }
      }
      
      block = {
        "inherits_from" => "base_section",
        "text" => {
          "text" => "Override text"
        }
      }
      
      result = instance.apply_block_inheritance(block, template_library)
      
      expect(result["type"]).to eq("section")
      expect(result["text"]["text"]).to eq("Override text")
      expect(result["text"]["type"]).to eq("mrkdwn") # Inherited
      expect(result["accessory"]["image_url"]).to eq("base.png") # Inherited
      expect(result["_inherits_from"]).to eq("base_section") # Reference preserved
    end
    
    it "raises an error if parent template is not found" do
      block = { "inherits_from" => "non_existent" }
      
      expect {
        instance.apply_block_inheritance(block, {})
      }.to raise_error(/Parent template 'non_existent' not found/)
    end
    
    it "returns the original block if no inheritance is specified" do
      block = { "type" => "section", "text" => "Some text" }
      
      result = instance.apply_block_inheritance(block, {})
      
      expect(result).to eq(block)
    end
  end
  
  describe "#replace_placeholders_recursive" do
    it "replaces placeholders in strings" do
      obj = "Hello {{name}}"
      custom_vars = { "name" => "World" }
      
      result = instance.replace_placeholders_recursive(obj, {}, custom_vars)
      
      expect(result).to eq("Hello World")
    end
    
    it "replaces placeholders in hashes" do
      obj = {
        "greeting" => "Hello {{name}}",
        "farewell" => "Goodbye {{name}}"
      }
      custom_vars = { "name" => "World" }
      
      result = instance.replace_placeholders_recursive(obj, {}, custom_vars)
      
      expect(result["greeting"]).to eq("Hello World")
      expect(result["farewell"]).to eq("Goodbye World")
    end
    
    it "replaces placeholders in arrays" do
      obj = ["Hello {{name}}", "Goodbye {{name}}"]
      custom_vars = { "name" => "World" }
      
      result = instance.replace_placeholders_recursive(obj, {}, custom_vars)
      
      expect(result[0]).to eq("Hello World")
      expect(result[1]).to eq("Goodbye World")
    end
    
    it "replaces item-specific placeholders" do
      obj = "Feature: {{item.name}}"
      item_data = { "name" => "Dynamic Blocks" }
      
      result = instance.replace_placeholders_recursive(obj, item_data, {})
      
      expect(result).to eq("Feature: Dynamic Blocks")
    end
    
    it "handles non-string values" do
      obj = 42
      
      result = instance.replace_placeholders_recursive(obj, {}, {})
      
      expect(result).to eq(42)
    end
  end
end
