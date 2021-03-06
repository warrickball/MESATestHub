class Version < ApplicationRecord
  validates_presence_of :number
  validates_uniqueness_of :number

  has_many :test_case_versions, dependent: :destroy
  has_many :test_instances, through: :test_case_versions, dependent: :destroy

  has_many :test_cases, through: :test_case_versions
  has_many :computers, through: :test_instances
  has_many :users, through: :computers

  paginates_per 25

  def self.tested_between(start_date, stop_date=DateTime.now)
    Version.includes(test_case_versions: [:test_case, :test_instances]).find(
      TestCaseVersion.where(last_tested: start_date..stop_date).pluck(:version_id).uniq
    )
  end


  # array of arrays. First element is array of test cases that pass all
  # instances. Second element is array of test cases that pass and fail at
  # at least once each. Third element is array of test cases that fail all
  # instances.
  def passing_mixed_failing_test_cases
    passing = []
    mixed = []
    failing = []
    # pass_some = some_passing_test_cases
    # fail_some = some_failing_test_cases
    test_cases.uniq.sort { |t1, t2| t1.name <=> t2.name }.each do |test_case|
      case status(test_case)
      when 0 then passing << test_case
      when 1 then failing << test_case
      when 2 then mixed << test_case
      end
      # if pass_some.include?(test_case) && fail_some.include?(test_case)
      #   mixed << test_case
      # elsif pass_some.include?(test_case)
      #   passing << test_case
      # elsif fail_some.include?(test_case)
      #   failing << test_case
      # end
    end
    [passing, mixed, failing]
  end

  def passing_mixed_failing_checksums_other_test_case_versions
    @passing = []
    @mixed = []
    @failing = []
    @checksums = []
    @other = []
    # pass_some = some_passing_test_cases
    # fail_some = some_failing_test_cases
    test_case_versions.includes(:test_instances).uniq.sort do |t1, t2|
      t1.test_case.name <=> t2.test_case.name
    end.each do |tcv|
      case tcv.status
      when 0 then @passing << tcv
      when 1 then @failing << tcv
      when 2 then @checksums << tcv
      when 3 then @mixed << tcv
      else
        @other << tcv
      end
      # if pass_some.include?(test_case) && fail_some.include?(test_case)
      #   mixed << test_case
      # elsif pass_some.include?(test_case)
      #   passing << test_case
      # elsif fail_some.include?(test_case)
      #   failing << test_case
      # end
    end
    [@passing, @mixed, @failing, @checksums, @other]
  end


  def passing
    @passing || passing_mixed_failing_checksums_other_test_case_versions[0]
  end

  def mixed
    @mixed || passing_mixed_failing_checksums_other_test_case_versions[1]
  end

  def failing
    @failing || passing_mixed_failing_checksums_other_test_case_versions[2]
  end

  def checksums
    @checksums || passing_mixed_failing_checksums_other_test_case_versions[3]
  end

  def other
    @other || passing_mixed_failing_checksums_other_test_case_versions[-1]
  end

  def computer_specs
    # special call that collects a version's test instances and groups them
    # by unique combinations of computer and computer specificaiton, and
    # ONLY gathers that information
    tis = TestInstance.where(version_id: id)
                      .select('computer_id, computer_specification')
                      .group('computer_id, computer_specification')
    # now build up a dictionary that maps one specificaiton to a list of
    # computers (multiple computers may have the same spec, though in practice,
    # it's rare)
    specs = {}
    tis.each do |ti|
      specs[ti.computer_specification] = 
        (specs[ti.computer_specification] || []) + [ti.computer_id]
    end
    # convert to Computer objects instead of ids
    specs.keys.each do |spec|
      specs[spec] = Computer.find(specs[spec])
    end
    specs
  end

  def statistics
    { passing: test_case_versions.where(status: 0).count,
      mixed: test_case_versions.where(status: 3).count,
      failing: test_case_versions.where(status: 1).count,
      checksums: test_case_versions.where(status: 2).count,
      other: test_case_versions.where(status: -1).count
    }
    # passing, mixed, failing = passing_mixed_failing_test_cases
    # stats[:passing] = passing.length
    # stats[:mixed] = mixed.length
    # stats[:failing] = failing.length
    # stats
  end

  def computers_count
    test_case_versions.pluck(:computer_count).max
  end

  def status(test_case=nil)
    if test_case.nil?
      # get status for whole revision
      statuses = self.test_case_versions.pluck(:status).uniq
      if statuses.count.zero?
        # if there are no resulsts, return -1, meaning not tested/error
        -1
      elsif statuses.min < 0
        # if there's a single error test case, return it as the whole status
        statuses.min
      else
        # return the max (mixed most important, then mixed checksums, then
        # then failures, then all successes)
        statuses.max
      end
    else
      # get status for a particular test case
      TestCaseVersion.find_or_create_by(version: self, test_case: test_case).status
    end
  end

  def diff_status(test_case)
    if test_instances.loaded?
      test_case_instances = test_instances.select do |ti|
        ti.test_case_id == test_case.id
      end
      # don't do the database call
      diff_count = test_case_instances.select { |ti| ti.diff == 1 }.length
      # 1 = at least one instance ran a diff
      return 1 if diff_count > 0
      no_diff_count = test_case_instances.select { |ti| ti.diff == 0 }.length
      # 0 = literally zero tests did a diff, and we know it
      return 0 if no_diff_count == test_case_instances.length
    else
      diff_count = test_instances.where(test_case: test_case, diff: 1).count
      # 1 = at least one instance ran a diff
      return 1 if diff_count > 0
      no_diff_count = test_instances.where(test_case: test_case, diff: 0).count
      total_count = test_instances.where(test_case: test_case).count
      # 0 = literally zero tests did a diff, and we know it
      return 0 if no_diff_count == total_count
    end
    # still here? Then no tests report having run diff, but at least one
    # didn't report what it was
    return 2
  end



  # gives overall status, # of passing tests, # of failing tests, and 
  # # of mixed tests
  def summary_status
    pass_count = 0
    fail_count = 0
    mix_count = 0
    checksum_count = 0
    other_count = 0
    test_case_versions.each do |tcv|
      case tcv.status
      when 0 then pass_count += 1
      when 1 then fail_count += 1
      when 2 then checksum_count += 1
      when 3 then mix_count += 1
      else
        other_count += 1
      end
    end
    # status = if other_count.positive?
    #            -1 # something weird happened with at least one test, scream about this
    #          elsif mix_count.positive?
    #            3  # at least one mixed results test. This is important
    #          elsif checksum_count.positive?
    #            2  # no mixed tests, but at least one with inconsistent checksums
    #          elsif fail_count.positive?
    #            1  # no checksum or mixed problems, but one test fails everyone
    #          elsif pass_count.positive?
    #            0  # no troublesome tests at all, we're passing and good!
    #          else
    #            -2 # no tests of any kind; we didn't test anything
    #          end
    # status = if [pass_count, fail_count, mix_count, checksum_count, other_count].sum.zero?
    #            3  # not tested
    #          elsif [fail_count, mix_count, checksum_count, other_count].sum.zero?
    #            0  # all passing
    #          elsif [mix_count, checksum_count, other_count].sum.zero?
    #            1  # some tests fail on all computers; call this failing
    #          elsif [checksum_count, other_count].sum.zero?].sum.zero?
    #            2  
    #          end
    return self.status, pass_count, fail_count, mix_count, checksum_count, other_count
  end

  # update compilation success/fail counts and corresponding compilation status
  def adjust_compilation_status(new_compilation_boolean, computer)
    # Guide: nil = untested (or unreported)
    #          0 = compiles on all systems so far
    #          1 = fails compilation on all systems so far
    #          2 = mixed results
    # this method just keeps this scheme logically consistent when a new report
    # rolls in, but it DOES NOT save the result to the database.
    return if computers.include? computer
    if new_compilation_boolean
      self.compile_success_count += 1
    else
      self.compile_fail_count += 1
    end

    self.compilation_status = if self.compile_fail_count == 0
                                0
                              else
                                if self.compile_success_count == 0
                                  1
                                else
                                  2
                                end
                              end
  end

  def problem_test_case_versions(depth: 100, runtime_threshold: 4,
    memory_threshold: 4)
    # Create massive structure from hashes detailing slow and inefficient cases
    # 
    # Structure goes:
    # - test_case
    #   - :runtime
    #     - :rn
    #       - computers
    #         - instance
    #         - average
    #         - standard deviation
    #     - :re (same as rn)
    #     - :total (same as rn)
    #   - :memory (same as :runtime)
    #   
    # So to get at a particular total runtime, you'd need to do something like
    #   res[test_case][:runtime][:total][computer][instance][:total_runtime_seconds]
    # 
    # The goal is to get everything in one place so further database calls
    # need not be made. The parameters determine how far back to do the search
    # to build baseline statistics and how sensitive the searches should be.
    # 
    # +depth+:: how many versions to go back to determine average and standard deviations
    # +runtime_threshold+:: how many stdevs from the average a time must be to be "slow"
    # +memory_threshold+:: how many stdevs from the average a memory usage must be to be "inefficient"
    

    # do pedantic loading of test case versions to ensure loading of computers
    # and test instances... there's probably a better rails way to do this
    tcvs = TestCaseVersion.where(version: self).includes(:computers, :test_instances)

    res = {}

    tcvs.each do |tcv|
      # create template hash; we'll delete empty ones later
      res[tcv] = {}

      # TestCaseVersion does heavy lifting of finding weak computer/cases
      runtime_data = tcv.slow_instances(depth: depth,
        threshold: runtime_threshold)
      memory_data = tcv.inefficient_instances(depth: depth,
        threshold: memory_threshold)

      # Thread together data from TestCaseVersion details
      res[tcv][:runtime] = runtime_data unless runtime_data.empty?
      res[tcv][:memory] = memory_data unless memory_data.empty?

      # trash entry if neither runtime nor memory problems appear
      res.delete(tcv) if res[tcv].empty?
    end
    res
  end



  def slow_test_case_versions(depth: 50, percent: 30)
    res = {}
    test_case_versions.includes(:test_case).where(status: 0).each do |tcv|
      faster = tcv.faster_past_instances(depth: depth, percent: percent)

      # skip only if all run types are the same AND one (hence all) are empty
      if faster.values.uniq.length == 1 && faster[faster.keys.first].empty?
        next
      else
        res[tcv] = faster
      end
    end
    # just in case, remove any keys with no values; doesn't seem to work...
    res.each_pair { |key, value| res.delete(key) if value.empty? }
    res
  end

  def inefficient_test_case_versions(depth: 50, percent: 10)
    res = {}
    test_case_versions.includes(:test_case).where(status: 0).each do |tcv|
      more_efficient = tcv.more_efficient_past_instances(
        depth: depth, percent: percent)

      # skip only if all run types are the same AND one (hence all) are empty
      if more_efficient.values.uniq.length == 1 &&
         more_efficient[more_efficient.keys.first].empty?
        next
      else
        res[tcv] = more_efficient
      end
    end
    # just in case, remove any keys with no values; doesn't seem to work...
    res.each_pair { |key, value| res.delete(key) if value.empty? }
    res
  end

  def last_tested(test_case=nil)
    test_case_versions.pluck(:last_tested).max
  end


  def to_s
    "#{self.number}"
  end

end
