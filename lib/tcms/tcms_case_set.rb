#!/usr/bin/env ruby

module VerificationTests
  class TCMSCaseSet
    @cases = []

    def to_array
      return @cases
    end
    alias :to_a :to_array

    def initialize( cases )
      raise "need array" unless cases.respond_to?("[]")
      @cases = cases
    end

    def self.expression(string_expr, tcms)
      sets = {}

      unless string_expr =~ /^[-a-z0-9A-Z_+)(. &]+$/
        raise "expression must contain only these chars: [-a-z0-9A-Z_+)(. ]"
      end

      expr = string_expr.split(" ")

      expr.each { |el|
        unless el =~ /^(?:[-a-z0-9A-Z_)(.]+|[-+)(&])$/
          raise "expression must contain only words with tag names or +, ) or ("
        end
      }

      # populate sets
      expr.collect! { |el|
        case el
        when /^[-+)(&]$/
          el
        when /^[-a-z0-9A-Z_)(.]+$/
          sets[el] = TCMSCaseSet.new(tcms.get_cases_by_tags([el]))
          "sets['#{el}']"
        else
          raise "expression is likely incorrect but developer screwed up too - can't handle: #{el}"
        end
      }

      return eval(expr.join(" "))
    end

    def +(set_or_array_of_cases)
      res = @cases.dup
      set_or_array_of_cases.each { |_case|
        res << _case unless res.find_index{ |c| c['case_id'] == _case['case_id'] }
      }
      return TCMSCaseSet.new(res)
    end

    def &(set_or_array_of_cases)
      res = []
      set_or_array_of_cases.each { |_case|
        res << _case if @cases.find_index{ |c| c['case_id'] == _case['case_id'] }
      }
      return TCMSCaseSet.new(res)
    end

    def -(set_or_array_of_cases)
      res = @cases.dup
      set_or_array_of_cases.each { |_case|
        res.delete_if { |c| c['case_id'] == _case['case_id'] }
      }
      return TCMSCaseSet.new(res)
    end

    def each
      if block_given?
        @cases.each{|c| yield(c)}
      else
        return @cases.each
      end
    end
  end
end
