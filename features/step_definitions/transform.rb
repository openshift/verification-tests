# we should not touch the original table!
# - especially for iteration over ScenarioOutline
Transform /.+/ do |arg|

  # @param [String] str to be expanded
  # @return string with expanded evaluation of expressions
  # @note original string object should never be modified here
  expand_str = proc do |str|
    begin
      x = str
      # handle cases like <user-max_gears-2> -> value of @user[:max_gears]-2
      #   this is disabled for v3 as it is complicated and has little/no use
      # x = str.gsub(/<(\w+)-([\w\_]+)(.*)??\>/, "<%=@\\1[:\\2]\\3%>")
      # substitute inline expressions
      x = x.gsub(/<%=(.+?)%>/m) { |c|
        eval $1
      }
    rescue => e
      Kernel::puts "Expand ERROR with argument: " + str.to_s + "\n" +
                                                    exception_to_string(e)
      x = str
    end
    x
  end

  x = arg
  begin
    if x.respond_to? :raw
      modified_args = x.raw.map{ |row|
        row.map { |cell|
          expand_str.call(cell)
        }
      }
      x = table(modified_args) #must be different than given _ARG_
    else #for non-table -> inline expansion
      x = expand_str.call(x)
    end
  rescue => e
    Kernel::puts "Transform ERROR: " + e.message + "\nwith argument: " + arg.to_s + "\n" + e.backtrace.join("\n")
    # x already points at original object if we are here
  end
  x
end
