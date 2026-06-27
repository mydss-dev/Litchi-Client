type PendingAction =
  | { type: 'authorize' }
  | { type: 'bindoss' }
  | { type: 'signconfig' }
  | { type: 'build' }
  | { type: 'setlatest_platform' }
  | { type: 'setlatest_url'; platform: 'windows' | 'android' | 'macos' };

const pendingActions = new Map<number, PendingAction>();

export function setPendingAction(userId: number, action: PendingAction): void {
  pendingActions.set(userId, action);
}

export function getPendingAction(userId: number): PendingAction | undefined {
  return pendingActions.get(userId);
}

export function clearPendingAction(userId: number): void {
  pendingActions.delete(userId);
}
