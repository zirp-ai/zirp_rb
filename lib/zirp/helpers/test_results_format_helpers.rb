# frozen_string_literal: true

# Module for formatting test results in release notes
module TestResultsFormatHelpers
  def parse_junit_test_results(file_path)
    # Parses JUnit XML and formats results into markdown
    doc = Nokogiri::XML(File.open(file_path))

    markdown = ""
    total_tests = doc.at("testsuite")["tests"].to_i
    failed_tests = doc.at("testsuite")["failures"].to_i

    if failed_tests.positive?
      markdown += "*Total Tests:* #{total_tests}\n"
      markdown += "*Failed Tests:* #{failed_tests}\n"
      doc.css("testcase").each do |testcase|
        next unless testcase.at("failure")

        name = testcase["name"]
        message = testcase.at("failure")["message"]
        stacktrace = testcase.at("failure").text.strip
        markdown += "\n*Test Case:* #{name}\n"
        markdown += "*Message:* #{message}\n"
        markdown += "*Stacktrace:*\n```\n#{stacktrace}\n```\n"
      end
    else
      markdown = "All tests passed successfully!"
    end
    markdown
  end
end
