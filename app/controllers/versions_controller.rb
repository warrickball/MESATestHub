class VersionsController < ApplicationController

  skip_before_action :verify_authenticity_token, only: [:submit_revision]

  def index
    @versions = Version.order(number: :desc)
                       .includes(:test_case_versions)
                       .page(params[:page])
    @row_classes = {}
    @pass_counts = {}
    @fail_counts = {}
    @mix_counts = {}
    @checksum_counts = {}
    @other_counts = {}
    # @case_counts = {}
    @last_tested = {}
    @versions.each do |version|
      status, pass_count, fail_count, mix_count, checksum_count, other_count = version.summary_status
      @row_classes[version] = case status
                              when 0 then 'table-success'
                              when 1 then 'table-danger'
                              when 2 then 'table-primary'
                              when 3 then 'table-warning'
                              else
                                'table-info'
                              end
      @pass_counts[version] = pass_count
      @fail_counts[version] = fail_count
      @mix_counts[version] = mix_count
      @checksum_counts[version] = checksum_count
      @other_counts[version] = other_count
      # @case_counts[version] = version.test_cases.uniq.length
    end
  end

  def show
    @mesa_versions = Version.order(number: :desc).pluck(:number)
    @selected = params[:number] || 'latest'
    @version_number = case @selected
                      when 'latest' then @mesa_versions.max
                      else
                        @selected.to_i
                      end
    @version = Version.find_by(number: @version_number)
    return unless @version

    # @test_case_versions = [@version.other, @version.mixed, @version.checksums,
    #                        @version.failing, @version.passing].flatten
    # trying to optimize db call
    @test_case_versions = @version.test_case_versions.includes(:test_case, test_instances: :computer).to_a
    @test_case_versions.sort_by! { |tcv| tcv.test_case.name }

    # get subsets by status. This duplicates code from Version model, but it
    # saves tons of database calls.
    @others = @test_case_versions.select { |tcv| !(0..3).include? tcv.status }
    @mixed = @test_case_versions.select { |tcv| tcv.status == 3 }
    @checksums = @test_case_versions.select { |tcv| tcv.status == 2 }
    @failing = @test_case_versions.select { |tcv| tcv.status == 1 }
    @passing = @test_case_versions.select { |tcv| tcv.status == 0 }
    @test_case_versions = [@others, @mixed, @checksums, @failing, @passing].flatten

    @header_text = "Test Cases Tested on Version #{@version_number}"
    @specs = @version.computer_specs
    @statistics = {
      passing: @test_case_versions.select { |tcv| tcv.status.zero? }.count,
      mixed: @test_case_versions.select { |tcv| tcv.status == 3 }.count,
      failing: @test_case_versions.select { |tcv| tcv.status == 1 }.count,
      checksums: @test_case_versions.select { |tcv| tcv.status == 2 }.count,
      other: @test_case_versions.select { |tcv| !(0..3).include? tcv.status }.count
    }

    # giant structure that holds all relevant counts for displaying badges next
    # to test case versions
    @counts = {}
    @failing_instances = {}
    @failure_types = {}
    @checksum_groups = {}
    @test_case_versions.each do |tcv|
      unique_checksums = tcv.test_instances.map { |ti| ti.checksum }.uniq
      unique_checksums.reject! { |checksum| checksum.nil? || checksum.empty? }

      if unique_checksums.count > 1
        @checksum_groups[tcv] = {}
        unique_checksums.each do |checksum|
          # more than one checksum? group computers, sorted by name, as values
          # in a hash accessed by their matching checksums
          @checksum_groups[tcv][checksum] = tcv.test_instances.select do |ti|
            ti.checksum == checksum
          end.map { |ti| ti.computer }.uniq.sort_by { |comp| comp.name.downcase }
        end
      end

      @failing_instances[tcv] = tcv.test_instances.select { |ti| !ti.passed }
      if @failing_instances[tcv].count.positive?
        @failure_types[tcv] = {}
        # create hash that has failure types as keys and arrays of computers,
        # sorted by name, as values
        @failing_instances[tcv].pluck(:failure_type).uniq.each do |failure_type|
          @failure_types[tcv][failure_type] = @failing_instances[tcv].select do |ti|
            ti.failure_type == failure_type
          end.map { |ti| ti.computer }.uniq.sort_by { |comp| comp.name }
        end
      end
      @counts[tcv] = {}
      @counts[tcv][:computers] = tcv.computer_count
      @counts[tcv][:passes] = tcv.test_instances.count { |ti| ti.passed }
      @counts[tcv][:failures] = @failing_instances[tcv].count
      @counts[tcv][:checksums] = tcv.unique_checksum_count
    end

    @version_status = case @version.status
                      when 0 then :passing
                      when 1 then :failing
                      when 2 then :checksum
                      when 3 then :mixed
                      when -1 then :other
                      else
                        :untested
                      end

    @status_text = case @version_status
                   when :passing then 'All tests passing on all computers.'
                   when :mixed
                     'Some tests fail on some computers and pass on others.'
                   when :failing then 'Some tests fail with all computers.'
                   when :checksum then 'Some tests pass with different checksums on different computers.'
                   when :other then 'Some tests have anomalous results.'
                   else
                     'No tests have been run for this version.'
                   end

    @status_class = case @version_status
                    when :passing then 'text-success'
                    when :mixed then 'text-warning'
                    when :failing then 'text-danger'
                    when :checksum then 'text-primary'
                    else
                      'text-info'
                    end
    @compilation_text = case @version.compilation_status
                        when 0 then 'Successfully compiling on ' +
                                    "#{@version.compile_success_count} " +
                                    'machines.'
                        when 1 then 'Failing to compile on ' \
                                    "#{@version.compile_fail_count} machines."
                        when 2 then 'Successfully compiling on ' \
                                    "#{@version.compile_success_count} and " \
                                    'failing to compile on ' \
                                    "#{@version.compile_fail_count} machines."
                        else
                          ''
                        end

    @compilation_class = case @version.compilation_status
                         when 0 then 'text-success'
                         when 1 then  'text-danger'
                         when 2 then 'text-warning'
                         else
                           0
                         end

    # set up colored table rows depending on passage status
    @row_classes = {}
    @last_tested = {}
    @test_case_versions.each do |tcv|
      @last_tested[tcv] = tcv.last_tested
      @row_classes[tcv] =
        case tcv.status
        when 0 then 'table-success'
        when 1 then 'table-danger'
        when 2 then 'table-primary'
        when 3 then 'table-warning'
        else
          'table-info'
        end
    end
  end 

  def show_version
    # puts "redirecting to #{version_path(params[:number])}"
    redirect_to version_path(params[:number])
  end

  # FOR SUBMITTING WHOLE REVISIONS

  # POST /versions/submit_revision.json
  def submit_revision
    # this sets up @user
    submission_fail_authenticate unless submission_authenticated?

    # now set up @computer
    @computer = @user.computers.find_by(name: user_params[:computer])
    submission_fail_computer if @computer.nil?

    # save/update version and quit if compilation failed
    submit_version
    unless version_params.include?(:compiled) && !version_params[:compiled]
      # do single call to database to get test cases, hash them for easy
      # retrieval
      # NOTE: new test cases will not be found by this query. submit_instance
      # needs to take care of this
      @test_case_hash = {}
      TestCase.where(name: test_instance_pairs.map do |instance_pair|
        extra_params(instance_pair)[:test_case]
      end).each do |tc|
        @test_case_hash[tc.name] = tc
      end


      # iterate through each test case and submit each as an instance
      # collect failed save attempts along the way (successful submissions return
      # nil, so only hold onto non-nil results). Skip all this if compilation
      # failed in the first place
      failures = test_instance_pairs.map do |instance_pair|
        submit_instance(instance_params(instance_pair),
                        extra_params(instance_pair))
      end.reject { |elt| elt.nil? }
      # if some failed, send back a failure message at the end
      unless failures.empty?
        errors = failures.map { |ti| ti.errors }
        respond_to do |format|
          format.json { render json: errors.to_json, status: :unprocessable_entity }
        end
        return
      end
    end

    respond_to do |format|
      format.json do
        render :show, status: :created, location: version_path(@version.number)
      end
    end
  end

  def submit_version
    # first find/create version
    @version = Version.find_or_create_by(number: version_params[:number])
    # check/update svn data
    @version.author = version_params[:author] if version_params[:author]
    @version.log = version_params[:log] if version_params[:log]

    # this param should (unless things change since January 25, 2018) only
    # be present if user called `install_and_test_revision` or `submit_revision`
    # with `mesa_test` where it will know if compilation was successful
    if version_params.include? :compiled
      @version.adjust_compilation_status(version_params[:compiled], @computer)
    end
    
    # bail out and report failure if we can't even get the version right
    unless @version.save
      respond_to do |format|
        format.json do
          render json: @version.errors, status: :unprocessable_entity
        end
      end
    end
  end

  def submit_instance(ti_params, extra_params)
    # set up basic test instance
    test_instance = TestInstance.new(ti_params)
    test_instance.version = @version
    test_instance.mesa_version = @version.number

    # set up associations
    test_instance.set_computer(@user, @computer)

    # if test case already exists, should have been loaded into @test_case_hash
    if @test_case_hash.include? extra_params[:test_case]
      test_instance.test_case = @test_case_hash[extra_params[:test_case]]
    else
      # if not, set_test_case_name will create the test case for us
      test_instance.set_test_case_name(extra_params[:test_case],
        extra_params[:mod])
    end

    # test_instance.set_test_case_name(extra_params[:test_case],
    #                                  extra_params[:mod])
    # test_instance.set_computer_name(@user, user_params[:computer])

    # return nil if we successfully save, otherwise the failed test_instance
    if test_instance.save
      nil
    else
      test_instance
    end
  end

  private

  def submission_authenticated?
    # If logged on to website, we're good
    @user = current_user
    authenticated = !@user.nil?

    # If not logged on, or submitting via JSON post (likely), check params
    unless authenticated
      @user = User.find_by(email: user_params[:email])
      authenticated = @user && @user.authenticate(user_params[:password])
    end
    authenticated
  end

  def submission_fail_authenticate
    # what to do when authentication during a submit fails
    respond_to do |format|
      format.html do
        redirect_to login_url,
                    alert: 'Must be signed in to submit a revision.'
      end
      format.json do
        render json: { error: 'Invalid e-mail or password.' },
               status: :unprocessable_entity
      end
    end
  end

  def submission_fail_computer
    # what to do when authentication during a submit fails
    respond_to do |format|
      format.html do
        redirect_to login_url,
                    alert: "Computer #{@computer.name} doesn't belong to " \
                           "user #{@user.name}."
      end
      format.json do
        render json: { error: %q{Computer doesn't belong to user.} },
               status: :unprocessable_entity
      end
    end
  end

  def version_params
    params.require(:version).permit(:number, :log, :author, :compiled)
  end

  def test_instance_pairs
    params.require(:instances)
  end

  def user_params
    params.require(:user).permit(:email, :password, :computer)
  end

  def instance_params(instance_pair)
    instance_pair.require(:test_instance).permit(
      :runtime_seconds, :omp_num_threads, :compiler, :compiler_version,
      :platform_version, :passed, :failure_type, :success_type, :steps,
      :retries, :backups, :summary_text, :diff, :checksum,
      :total_runtime_seconds, :re_time, :rn_mem, :re_mem)
  end

  def extra_params(instance_pair)
    instance_pair.require(:extra).permit(:test_case, :mod)
  end


end
