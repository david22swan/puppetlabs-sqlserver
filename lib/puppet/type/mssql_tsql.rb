require 'puppet'
require 'puppet/property/login'

Puppet::Type::newtype(:mssql_tsql) do
  newparam :name, :namevar => true

  def self.newcheck(name, options = {}, &block)
    @checks ||= {}

    check = newparam(name, options, &block)
    @checks[name] = check
  end

  def self.checks
    @checks.keys
  end

  desc 'command to run against an instance with the authenticated credentials used in mssql::config'
  newparam(:command) do

  end

  desc 'requires the usage of mssql::config with the user and password'
  newparam(:instance) do

  end

  desc 'SQL Query to run and only run if exits with non-zero'
  newcheck(:onlyif) do
    # Return true if the command returns 0.
    def check(value)
      begin
        output = provider.run(value)
      end
      debug("OnlyIf returned exitstatus of #{output.exitstatus}")
      output.exitstatus != 0
    end
  end

  def check_all_attributes(refreshing = false)
    check = :onlyif
    if @parameters.include?(check)
      val = @parameters[check].value
      val = [val] unless val.is_a? Array
      val.each do |value|
        return false unless @parameters[check].check(value)
      end
    end
    true
  end

  def output
    if self.property(:returns).nil?
      return nil
    else
      return 0
    end
  end

  def refresh
    if self.check_all_attributes(true)
      provider.run_update
    end
  end

  newproperty(:returns, :array_matching => :all, :event => :executed_command) do |property|
    munge do |value|
      value.to_s
    end

    def event_name
      :executed_command
    end

    defaultto "0"

    attr_reader :output

    # Make output a bit prettier
    def change_to_s(currentvalue, newvalue)
      "executed successfully"
    end

    # First verify that all of our checks pass.
    def retrieve
      # We need to return :notrun to trigger evaluation; when that isn't
      # true, we *LIE* about what happened and return a "success" for the
      # value, which causes us to be treated as in_sync?, which means we
      # don't actually execute anything.  I think. --daniel 2011-03-10
      if @resource.check_all_attributes
        return :notrun
      else
        return self.should
      end
    end

    # Actually execute the command.
    def sync
      event = :executed_command
      begin
        @output = provider.run_update
      end
      unless @output.exitstatus.to_s == "0"
        self.fail("#{self.resource[:command]} returned #{@output.exitstatus} instead of one of [#{self.should.join(",")}]")
      end
      event
    end
  end

  def self.instances
    []
  end


end