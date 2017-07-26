require 'spec_helper'

describe CreateDagJobs do

  describe '#call' do
    context 'for diamond workflow' do
      #    A
      #   / \
      #  B  C
      #  | /
      #  D
      #
      before do
        Workflow.delete_all
        Job.delete_all
        @w = create(:workflow)
      end

      it 'creates a job for each job description' do
        expect(Job.count).to eq 4
      end

      it 'calculates the number of dependencies for each job' do
        jobs = @w.jobs
        expect(jobs[0].dependencies_count).to eq 2
        expect(jobs[1].dependencies_count).to eq 1
        expect(jobs[2].dependencies_count).to eq 1
        expect(jobs[3].dependencies_count).to eq 0
      end
      it 'calculates the number of dependents for each job' do
        jobs = @w.jobs
        expect(jobs[0].dependents_count).to eq 0
        expect(jobs[1].dependents_count).to eq 1
        expect(jobs[2].dependents_count).to eq 1
        expect(jobs[3].dependents_count).to eq 2
      end

      it 'finds the the root jobs' do
        expect(@w.roots[0].job).to eq @w.jobs[3]
      end
    end

    context 'for multi-root workflow' do
      #    A   B
      #    \  /
      #     C
      #     |
      #     D
      #
      before do
        Workflow.delete_all
        Job.delete_all
        @w = create(:workflow_multi_root_definition)
      end

      it 'creates a job for each job description' do
        expect(Job.count).to eq 4
      end

      it 'finds 2 root jobs' do
        expect(@w.roots.length).to eq 2
      end

      it 'finds the root jobs' do
        expect(all_roots_found?).to eq true
      end

      def all_roots_found?
        (@w.roots.map {|r| r.job } & [@w.jobs[3], @w.jobs[2]]).any?
      end
    end
  end

end

