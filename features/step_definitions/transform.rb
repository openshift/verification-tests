# This is a hack for lack of global transformation in Cucumber 3 and later
# https://github.com/cucumber/cucumber-ruby/issues/1209
# Make sure this is compatible before any Cucumber upgrades.
#
# While on it, a non-hack possible approach is in the beginning of each step to
# call something like:
# transform binding, :arg1, :arg2, :arg3, :table
# where `transform` gets `arg1` from binding, evaluates and finally sets it to
# new value. Same with the rest of the args. This works but requires extra work
# for each step. If desired, that can easily be achieved by `sed` like:
# * find -type f -exec sed -r -i -e 's~(^\s*(Given|When|Then|And) .*\|(.*)\|)~\1\n  transform binding, \3~' '{}' \;
# * find -type f -exec sed -r -i -e '/^  transform binding,/s~,\s*~, :~g' '{}' \;
# * find -type f -exec sed -r -i -e '/^  transform binding,/s~\s$~~' '{}' \;
#
# The above approach is suitable in case future updates make the hack below
# hard to achieve. I found the point to intervene by `cucumber --tags @pry` then
# checking pry-backlog to find easiest point to intervene.
#
# Of course you can think of another way to achieve the same.

module BushSlicer
  module CucumberTransformHack
    def self.extended(p)
      class << p
        orig_method = instance_method(:cucumber_instance_exec_in)
        define_method(:cucumber_instance_exec_in) do |world, check_arity, pseudo_method, *args, &block|
          check_arity && world && !args.empty? && begin
            args = args.map { |a| world.transform_value a }
          rescue ArgumentError => e
            world.logger.error "very likely an imprecise condition in TransformHack where it catches non-step invocations"
            world.logger.error e
          end
          orig_method.bind(self).(world, check_arity, pseudo_method, *args, &block)
        end
      end
    end
  end
end

::Cucumber::Glue::InvokeInWorld.extend ::BushSlicer::CucumberTransformHack
