class TestInstance < ApplicationRecord
  @@success_types =  {
    'run_test_string' => 'Test String',
    'run_checksum' => 'Run Checksum',
    'photo_checksum' => 'Photo Checksum'
  }

  @@failure_types = {
    'run_test_string' => 'Test String',
    'final_model' => 'Final Model',
    'run_checksum' => 'Run Checksum',
    'run_diff' => 'Run Diff',
    'photo_file' => 'Missing Photo',
    'photo_checksum' => 'Photo Checkusm',
    'photo_diff' => 'Photo Diff',
    'compilation' => 'Compilation'
  }

  @@compilers = %w[gfortran ifort SDK]

  belongs_to :computer
  belongs_to :test_case
  belongs_to :version
  has_many :test_data, dependent: :destroy
  validates_presence_of :runtime_seconds, :version_id, :computer_id,
                        :test_case_id, :compiler
  # validates_inclusion_of :passed, in: [true, false]
  validates_inclusion_of :success_type, in: @@success_types.keys,
                                        allow_blank: true
  validates_inclusion_of :failure_type, in: @@failure_types.keys,
                                        allow_blank: true
  validates_inclusion_of :compiler, in: @@compilers

  def self.success_types
    @@success_types
  end

  def self.failure_types
    @@failure_types
  end

  def self.compilers
    @@compilers
  end

  # list of version numbers with test instances that have failed since a
  # particular date
  def self.failing_versions_since(date)
    Version.find(where(passed: false, created_at: date...Time.now)
      .pluck(:version_id).uniq).sort_by(&:number)
  end

  # list of version numbers with ONLY passing test cases
  def self.passing_versions_since(date)
    # all versions that have at least one passing test instance
    passing_something = Version.find(
      where(passed: true, created_at: date...Time.now)
      .pluck(:version_id).uniq
    ).sort_by(&:number)
    # remove versions that have even one failing test
    passing_something - failing_versions_since(date)
  end

  # list of test cases with instances that failed for a particular version
  # since a particular date
  def self.failing_cases_since(date, version)
    TestCase.find(where(passed: false)
                    .where(created_at: date...Time.now)
                    .where(version: version)
                    .pluck(:test_case_id)).sort_by(&:name)
  end

  def computer_specification
    spec = ''
    spec += computer.platform + ' ' if computer.platform
    spec += platform_version + ' ' if platform_version
    spec += compiler + ' ' if compiler
    spec += compiler_version if compiler_version
    return 'no specificaiton' if spec.empty?
    spec.strip
  end

  def data(name)
    test_data.where(name: name).order(updated_at: :desc).first.value
  end

  def set_data(name, new_val)
    test_data.where(name: name).order(updated_at: :desc).first.value = new_val
  end

  def set_computer_name(user, new_computer_name)
    new_computer = user.computers.where(name: new_computer_name).first
    if new_computer.nil?
      errors.add :computer_id, 'Could not find computer with name ' \
        "\"#{new_computer_name}\"."
    else
      self.computer = new_computer
    end
  end

  def set_computer(user, computer)
    if computer.user == user
      self.computer = computer
    else
      errors.add :computer_id, "Computer #{computer.name} does not belong to "\
                               "user #{user.name}."
    end
  end

  # meant to ease transition from mesa_version to Version model.
  def update_version(do_save=false)
    # don't do anything if versions are both set (or if we are helpless)
    return if version_id && mesa_version
    return unless version_id || mesa_version
    # conditionally update the integer mesa_version
    if version_id
      self.mesa_version ||= version.number
    # conditionally update the version
    else
      self.version = Version.find_or_create_by(number: mesa_version)
    end
    save if do_save
  end

  # still useful to have direct access to mesa_version for sorting purposes
  def mesa_version
    return super if super
    self.update_attributes(mesa_version: version.number)
    super
  end  

  def set_test_case_name(new_test_case_name, mod, version_number=10000)
    new_test_case = TestCase.find_by(name: new_test_case_name)
    if new_test_case.nil?
      # no test case found, so just make one up
      # this test case will have NO EXTRA DATA ASSOCIATED WITH IT
      # at time of this edit (November 22, 2017), the data features is not in
      # use, but this may need to be revisited
      new_test_case = TestCase.create(
        name: new_test_case_name,
        module: mod,
        version_added: version_number
      )
      new_test_case.update_version_created
      # old behavior: scuttle the saving process
      # errors.add :test_case_id,
      #            'Could not find test case with name "' + new_test_case_name +
      #            '".'
    end
    self.test_case = new_test_case
  end

  # full text for passage status
  def passage_status
    if passed
      if success_type
        "PASS: #{TestInstance.success_types[success_type]}"
      else
        "PASS"
      end
    else
      if failure_type
        "FAIL: #{TestInstance.failure_types[failure_type]}"
      else
        "FAIL"
      end
    end
  end


  # make test_data easier to access as if they were attributes
  def method_missing(method_name, *args, &block)
    if test_case.data_names.include? method_name.to_s
      data(method_name.to_s)
    elsif test_case.data_names.include? method_name.to_s.chomp('=') and args.length > 0
      set_data(method_name.to_s.chomp('='), args[0])
    else
      super(method_name, *args, &block)
    end
  end
    
end
