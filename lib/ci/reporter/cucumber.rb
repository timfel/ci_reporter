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
        @current_feature_name = name.split("\n").first
      end

      def before_feature_element(feature_element)
        @test_suite = TestSuite.new("#{@current_feature_name} #{feature_element.instance_variable_get("@name")}")
        @test_suite.start
      end

      def after_feature_element(feature_element)
        @test_suite.finish
        @report_manager.write_report(@test_suite)
        @test_suite = nil
      end

      def before_step(step)
        @test_case = TestCase.new(step.name)
        @test_case.start
      end

      def after_step(step)
        if @test_case.nil? 
          $stderr << "Warning, no test case was started for #{step}. Time won't be logged."
          @test_case = TestCase.new(step.name)
          @test_case.start
        end
        @test_case.finish

        case step.status
        when :pending, :undefined
          @test_case.name = "#{@test_case.name} (PENDING)"
        when :skipped
          @test_case.name = "#{@test_case.name} (SKIPPED)"
        when :failed
          @test_case.failures << CucumberFailure.new(step)
        end

        if @test_suite.nil? 
          $stderr << "Warning, no test suite was started for the scenario around #{step}. Time logging will be wrong."
          @test_suite = TestSuite.new("#{@current_feature_name} Unspecified Feature Element")
          @test_suite.start
        end
        @test_case.finish
        @test_suite.testcases << @test_case
      end
    end
  end
end
