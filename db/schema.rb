# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20190415192153) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "computers", force: :cascade do |t|
    t.string "name", null: false
    t.string "platform"
    t.string "processor"
    t.integer "ram_gb"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["name"], name: "index_computers_on_name", unique: true
    t.index ["user_id"], name: "index_computers_on_user_id"
  end

  create_table "test_case_versions", force: :cascade do |t|
    t.bigint "version_id", null: false
    t.bigint "test_case_id", null: false
    t.integer "status", default: -1, null: false
    t.integer "submission_count", default: 0, null: false
    t.integer "computer_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_tested"
    t.index ["test_case_id"], name: "index_test_case_versions_on_test_case_id"
    t.index ["version_id"], name: "index_test_case_versions_on_version_id"
  end

  create_table "test_cases", force: :cascade do |t|
    t.string "name", null: false
    t.integer "version_added"
    t.text "description"
    t.string "datum_1_name"
    t.string "datum_1_type"
    t.string "datum_2_name"
    t.string "datum_2_type"
    t.string "datum_3_name"
    t.string "datum_3_type"
    t.string "datum_4_name"
    t.string "datum_4_type"
    t.string "datum_5_name"
    t.string "datum_5_type"
    t.string "datum_6_name"
    t.string "datum_6_type"
    t.string "datum_7_name"
    t.string "datum_7_type"
    t.string "datum_8_name"
    t.string "datum_8_type"
    t.string "datum_9_name"
    t.string "datum_9_type"
    t.string "datum_10_name"
    t.string "datum_10_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "module"
    t.bigint "version_id"
    t.index ["name"], name: "index_test_cases_on_name", unique: true
    t.index ["version_id"], name: "index_test_cases_on_version_id"
  end

  create_table "test_data", force: :cascade do |t|
    t.string "name", null: false
    t.string "string_val"
    t.float "float_val"
    t.integer "integer_val"
    t.boolean "boolean_val"
    t.bigint "test_instance_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["test_instance_id"], name: "index_test_data_on_test_instance_id"
  end

  create_table "test_instances", force: :cascade do |t|
    t.integer "runtime_seconds", null: false
    t.integer "mesa_version"
    t.integer "omp_num_threads"
    t.string "compiler"
    t.string "compiler_version"
    t.string "platform_version"
    t.boolean "passed", null: false
    t.bigint "computer_id", null: false
    t.bigint "test_case_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "success_type"
    t.string "failure_type"
    t.bigint "version_id"
    t.integer "steps"
    t.integer "retries"
    t.integer "backups"
    t.text "summary_text"
    t.integer "diff", default: 2
    t.bigint "test_case_version_id"
    t.string "checksum"
    t.string "computer_name"
    t.string "computer_specification"
    t.integer "total_runtime_seconds"
    t.integer "re_time"
    t.integer "rn_mem"
    t.integer "re_mem"
    t.index ["computer_id"], name: "index_test_instances_on_computer_id"
    t.index ["mesa_version"], name: "index_test_instances_on_mesa_version"
    t.index ["test_case_id"], name: "index_test_instances_on_test_case_id"
    t.index ["test_case_version_id"], name: "index_test_instances_on_test_case_version_id"
    t.index ["version_id"], name: "index_test_instances_on_version_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "name"
    t.string "password_digest"
    t.boolean "admin"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "time_zone", default: "Pacific Time (US & Canada)"
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.integer "number", null: false
    t.string "author"
    t.text "log"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "compilation_status"
    t.integer "compile_success_count", default: 0
    t.integer "compile_fail_count", default: 0
    t.index ["number"], name: "index_versions_on_number", unique: true
  end

  add_foreign_key "test_case_versions", "test_cases"
  add_foreign_key "test_case_versions", "versions"
  add_foreign_key "test_cases", "versions"
  add_foreign_key "test_data", "test_instances"
  add_foreign_key "test_instances", "computers"
  add_foreign_key "test_instances", "test_case_versions"
  add_foreign_key "test_instances", "test_cases"
  add_foreign_key "test_instances", "versions"
end
