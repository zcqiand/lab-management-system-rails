# frozen_string_literal: true

module Auth
  # 进程内 TTL 快照缓存（MenuSnapshotCache/MembershipSnapshotCache 合并镜像：
  # 同款 30min TTL + 按 userId 存取，miss/过期返 nil）。
  class SnapshotCache
    TTL_SECONDS = 30 * 60

    def initialize(ttl_seconds: TTL_SECONDS, clock: Time)
      @ttl = ttl_seconds
      @clock = clock
      @store = {}
    end

    def put(user_id, value)
      return if user_id.nil? || value.nil?

      @store[user_id] = { value: value, expires_at: @clock.now + @ttl }
    end

    def get(user_id)
      return nil if user_id.nil?

      entry = @store[user_id]
      return nil if entry.nil?
      return @store.delete(user_id) && nil if @clock.now.after?(entry[:expires_at])

      entry[:value]
    end

    def size
      @store.size
    end
  end
end
