# frozen_string_literal: true

# Module for helper methods for formatting messages across different platforms
module MessageFormatHelpers
  def process_placeholders(text, template)
    return text unless text.is_a?(String)

    template.each do |key, value|
      text.gsub!("{{#{key}}}", value)
    end
    text
  end

  def generate_section_block(block_data, custom_vars)
    section = Slack::BlockKit::Section.new
    if block_data["text"]
      text_type = block_data["text"]["type"]
      text_content = process_placeholders(block_data["text"]["text"], custom_vars)
      section.text(text_content, text_type: text_type)
    end
    block_data["fields"]&.each do |field|
      field_text = process_placeholders(field["text"], custom_vars)
      section.field(field_text, text_type: field["type"])
    end
    section
  end

  def generate_divider_block(_block_data, _custom_vars)
    Slack::BlockKit::Divider.new
  end

  def generate_actions_block(block_data, custom_vars)
    actions = Slack::BlockKit::Actions.new
    block_data["elements"].each do |element|
      button = Slack::BlockKit::Element::Button.new(
        text: process_placeholders(element["text"], custom_vars),
        url: process_placeholders(element["url"], custom_vars),
        style: element["style"]
      )
      actions.button(button)
    end
    actions
  end

  def generate_context_block(block_data, custom_vars)
    context = Slack::BlockKit::Context.new
    block_data["elements"].each do |element|
      text_content = process_placeholders(element["text"], custom_vars)
      context.element(text_content, text_type: element["type"])
    end
    context
  end

  def generate_file_block(block_data, custom_vars)
    Slack::BlockKit::File.new(
      external_id: process_placeholders(block_data["external_id"], custom_vars),
      source: block_data["source"]
    )
  end

  def generate_header_block(block_data, custom_vars)
    Slack::BlockKit::Header.new(text: process_placeholders(block_data["text"], custom_vars))
  end

  def generate_image_block(block_data, custom_vars)
    Slack::BlockKit::Image.new(
      image_url: process_placeholders(block_data["image_url"], custom_vars),
      alt_text: process_placeholders(block_data["alt_text"], custom_vars)
    )
  end

  def generate_input_block(block_data, custom_vars)
    Slack::BlockKit::Input.new(
      label: process_placeholders(block_data["label"], custom_vars)
    ).element(
      Slack::BlockKit::Element::PlainTextInput.new(action_id: block_data["action_id"])
    )
  end

  def generate_rich_text_block(block_data, custom_vars)
    Slack::BlockKit::RichText.new(text: process_placeholders(block_data["text"], custom_vars))
  end

  def generate_video_block(block_data, custom_vars)
    Slack::BlockKit::Video.new(
      title: process_placeholders(block_data.dig("title", "text"), custom_vars),
      video_url: process_placeholders(block_data["video_url"], custom_vars),
      alt_text: process_placeholders(block_data["alt_text"], custom_vars),
      thumbnail_url: process_placeholders(block_data["thumbnail_url"], custom_vars)
    )
  end

  def generate_junit_test_results_block(directory)
    junit_markdown = ""

    Find.find(directory) do |path|
      if File.file?(path) && File.extname(path) == ".xml"
        file_markdown = TestResultsFormatHelpers.parse_junit_test_results(path)
        junit_markdown += "\n# #{File.basename(path)}\n#{file_markdown}\n"
      end
    end
    Slack::BlockKit::Section.new.text(junit_markdown, text_type: "mrkdwn")
  end
end
