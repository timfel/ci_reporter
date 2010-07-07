# Copyright (c) 2006-2010 Nick Sieger <nicksieger@gmail.com>
# See the file LICENSE.txt included with the distribution for
# software license details.

require 'ci/reporter/core'
tried_gem = false
begin
  require 'cucumber'
rescue LoadError
  unless tried_gem
    tried_gem = true
    require 'rubygems'
    gem 'cucumber'
    retry
  end
end

module CI
  module Reporter
    class CucumberFailure
      attr_reader :step

      def initialize(step)
        @step = step
      end

      def failure?
        true
      end

      def error?
        !failure?
      end

      def name
        step.exception.class.name
      end

      def message
        step.exception.message
      end

      def location
        step.exception.backtrace.join("\n")
      end
    end

    class Cucumber

      def initialize(step_mother, io, options)
        @report_manager = ReportManager.new("features")
      end

      def before_feature_name(name)        
        @test_suite = TestSuite.new(name.split("\n").first)
        @test_suite.start
      end
      
      def after_feature_name(name)
        @test_suite.finish
        @report_manager.write_report(@test_suite)
        @test_suite = nil
      end

      def before_feature_element(feature_element)
        @test_case = TestCase.new(feature_element.instance_variable_get("@name"))
        @status = ""
        @test_case.start
      end

      def after_feature_element(feature_element)
        @test_case.finish
        @test_case.name = "#{@test_case.name} #{@status}".strip
        @test_suite.testcases << @test_case
      end

      def after_step(step)
        case step.status
        when :pending, :undefined
          @status = "(PENDING)" if @status.empty?
        when :skipped
          @status = "(SKIPPED)" unless @status == "(FAILED)"
        when :failed
          @status = "(FAILED)"
          @test_case.failures << CucumberFailure.new(step)
        end
      end
    end
  end
end
