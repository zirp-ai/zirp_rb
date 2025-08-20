# frozen_string_literal: true

module BlockBuilderHelpers
  # Dynamically generates blocks based on data
  # @param block_type [String] The type of block to generate
  # @param data [Array] Array of data items to generate blocks for
  # @param template [Hash] Template for how to structure each block
  # @param custom_vars [Hash] Custom variables for placeholders
  # @return [Array] Array of block hashes
  def generate_dynamic_blocks(block_type, data, template, custom_vars = {})
    data.map do |item|
      # Create a copy of the template for this item
      block = template.dup
      
      # Replace placeholders in the template with data from this item
      replace_placeholders_recursive(block, item, custom_vars)
      
      # Ensure the block has the correct type
      block["type"] = block_type
      
      block
    end
  end
  
  # Recursively replaces placeholders in a hash or array
  # @param obj [Hash, Array, String] The object to process
  # @param item_data [Hash] Data for the current item
  # @param custom_vars [Hash] Global custom variables
  # @return [Hash, Array, String] The processed object
  def replace_placeholders_recursive(obj, item_data, custom_vars)
    case obj
    when Hash
      obj.each do |k, v|
        obj[k] = replace_placeholders_recursive(v, item_data, custom_vars)
      end
    when Array
      obj.map! { |v| replace_placeholders_recursive(v, item_data, custom_vars) }
    when String
      # Replace {{item.field}} placeholders with values from item_data
      result = obj.dup
      item_data.each do |key, value|
        result.gsub!("{{item.#{key}}}", value.to_s)
      end
      
      # Also replace global placeholders
      custom_vars.each do |key, value|
        result.gsub!("{{#{key}}}", value.to_s)
      end
      
      result
    else
      obj
    end
  end
  
  # Applies a block template from the template library
  # @param template_name [String] Name of the template to use
  # @param template_library [Hash] Library of templates
  # @param overrides [Hash] Values to override in the template
  # @param custom_vars [Hash] Custom variables for placeholders
  # @return [Hash] The processed block
  def apply_block_template(template_name, template_library, overrides = {}, custom_vars = {})
    # Get the template from the library
    template = template_library[template_name]
    raise "Template '#{template_name}' not found in template library" unless template
    
    # Create a deep copy of the template
    block = Marshal.load(Marshal.dump(template))
    
    # Apply overrides
    apply_overrides(block, overrides)
    
    # Process any placeholders
    process_placeholders_in_block(block, custom_vars)
    
    block
  end
  
  # Recursively applies overrides to a block
  # @param block [Hash] The block to modify
  # @param overrides [Hash] The overrides to apply
  # @return [Hash] The modified block
  def apply_overrides(block, overrides)
    overrides.each do |key, value|
      if value.is_a?(Hash) && block[key].is_a?(Hash)
        # Recursively apply nested overrides
        apply_overrides(block[key], value)
      else
        # Direct override
        block[key] = value
      end
    end
    block
  end
  
  # Processes placeholders in a block
  # @param block [Hash] The block to process
  # @param custom_vars [Hash] Custom variables for placeholders
  # @return [Hash] The processed block
  def process_placeholders_in_block(block, custom_vars)
    replace_placeholders_recursive(block, {}, custom_vars)
  end
  
  # Applies inheritance to a block
  # @param block [Hash] The block to process
  # @param template_library [Hash] Library of templates
  # @return [Hash] The processed block with inheritance applied
  def apply_block_inheritance(block, template_library)
    # Check if this block inherits from another
    if block["inherits_from"]
      parent_name = block["inherits_from"]
      parent = template_library[parent_name]
      raise "Parent template '#{parent_name}' not found for inheritance" unless parent
      
      # Create a deep copy of the parent
      parent_copy = Marshal.load(Marshal.dump(parent))
      
      # Remove the inherits_from key from the child
      inherits_from = block.delete("inherits_from")
      
      # Apply the child's properties as overrides to the parent
      result = apply_overrides(parent_copy, block)
      
      # Restore the inherits_from for reference
      result["_inherits_from"] = inherits_from
      
      result
    else
      block
    end
  end
end
