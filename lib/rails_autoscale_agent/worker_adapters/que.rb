# frozen_string_literal: true

require 'rails_autoscale_agent/logger'

module RailsAutoscaleAgent
  module WorkerAdapters
    class Que
      include RailsAutoscaleAgent::Logger
      include Singleton

      attr_writer :queues

      def queues
        # Track the known queues so we can continue reporting on queues that don't
        # have enqueued jobs at the time of reporting.
        # Assume a "default" queue so we always report *something*, even when nothing
        # is enqueued.
        @queues ||= Set.new(['default'])
      end

      def enabled?
        if defined?(::Que)
          logger.info "Que enabled (#{Time.now.zone})"
          true
        end
      end

      def collect!(store)
        log_msg = String.new
        t = Time.now.utc

        queue = "default"

        currently_working_job_ids = ::Que.worker_states.collect { |x| x[:job_id] }
        next_job = DB[:que_jobs].order(:run_at).exclude(job_id: currently_working_job_ids).first

        run_at = next_job && next_job[:run_at]
        run_at = DateTime.parse(run_at) if run_at.is_a?(String)
        latency_ms = run_at ? ((t - run_at)*1000).ceil : 0
        latency_ms = 0 if latency_ms < 0

        store.push latency_ms, t, queue
        log_msg << "que.#{queue}=#{latency_ms} "

        logger.debug log_msg unless log_msg.empty?
      end
    end
  end
end
