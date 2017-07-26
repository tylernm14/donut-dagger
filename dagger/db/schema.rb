# encoding: UTF-8
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

ActiveRecord::Schema.define(version: 20170716022915) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "definitions", force: :cascade do |t|
    t.string   "name",                     null: false
    t.string   "description"
    t.jsonb    "data",        default: {}, null: false
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
  end

  add_index "definitions", ["name"], name: "index_definitions_on_name", using: :btree

  create_table "job_edges", force: :cascade do |t|
    t.integer  "workflow_id",   null: false
    t.integer  "dependency_id", null: false
    t.integer  "dependent_id",  null: false
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
  end

  add_index "job_edges", ["dependency_id"], name: "index_job_edges_on_dependency_id", using: :btree
  add_index "job_edges", ["dependent_id"], name: "index_job_edges_on_dependent_id", using: :btree
  add_index "job_edges", ["workflow_id"], name: "index_job_edges_on_workflow_id", using: :btree

  create_table "jobs", force: :cascade do |t|
    t.integer  "workflow_id",                               null: false
    t.uuid     "uuid",                                      null: false
    t.string   "name",                                      null: false
    t.jsonb    "description",                  default: {}, null: false
    t.integer  "status",                       default: 0,  null: false
    t.integer  "priority",                     default: 0,  null: false
    t.integer  "dependencies_count",           default: 0,  null: false
    t.integer  "dependencies_succeeded_count", default: 0,  null: false
    t.integer  "dependents_count",             default: 0,  null: false
    t.text     "stdout",                       default: ""
    t.text     "stderr",                       default: ""
    t.text     "messages",                     default: ""
    t.datetime "start_time"
    t.datetime "end_time"
    t.datetime "created_at",                                null: false
    t.datetime "updated_at",                                null: false
    t.string   "kube_job_name"
  end

  add_index "jobs", ["status"], name: "index_jobs_on_status", using: :btree
  add_index "jobs", ["uuid"], name: "index_jobs_on_uuid", using: :btree
  add_index "jobs", ["workflow_id"], name: "index_jobs_on_workflow_id", using: :btree

  create_table "roots", force: :cascade do |t|
    t.integer  "workflow_id", null: false
    t.integer  "job_id",      null: false
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  add_index "roots", ["job_id"], name: "index_roots_on_job_id", using: :btree
  add_index "roots", ["workflow_id"], name: "index_roots_on_workflow_id", using: :btree

  create_table "workflows", force: :cascade do |t|
    t.uuid     "uuid",                             null: false
    t.integer  "status",              default: 0,  null: false
    t.integer  "priority",            default: 0,  null: false
    t.integer  "user_oauth_id"
    t.string   "queue"
    t.string   "proc_queue"
    t.string   "messages",            default: [],              array: true
    t.uuid     "root_job_uuid"
    t.integer  "parallelism",         default: 1,  null: false
    t.integer  "launched_jobs_count", default: 0,  null: false
    t.datetime "start_time"
    t.datetime "end_time"
    t.datetime "created_at",                       null: false
    t.datetime "updated_at",                       null: false
    t.integer  "definition_id",                    null: false
  end

  add_index "workflows", ["definition_id"], name: "index_workflows_on_definition_id", using: :btree
  add_index "workflows", ["status"], name: "index_workflows_on_status", using: :btree
  add_index "workflows", ["uuid"], name: "index_workflows_on_uuid", using: :btree

end
