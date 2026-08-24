class AppStrings {
  AppStrings._();

  static const appName = 'You-Do';
  static const tagline = 'Set stakes. Get things done.';

  // Auth
  static const signIn = 'Sign In';
  static const signUp = 'Sign Up';
  static const emailHint = 'Email address';
  static const passwordHint = 'Password';
  static const continueWithGoogle = 'Continue with Google';
  static const alreadyHaveAccount = 'Already have an account? Sign in';
  static const dontHaveAccount = "Don't have an account? Sign up";

  // Tasks
  static const myTasks = 'My Tasks';
  static const newTask = 'New Task';
  static const editTask = 'Edit Task';
  static const taskTitle = 'Task title';
  static const taskDescription = 'Description (optional)';
  static const dueDate = 'Due Date & Time';
  static const financialStakes = 'Financial Stakes';
  static const rewardAmount = 'Reward if done on time (\$)';
  static const penaltyAmount = 'Penalty if missed (\$)';
  static const markComplete = 'Mark Complete';
  static const deleteTask = 'Delete Task';
  static const today = 'Today';
  static const upcoming = 'Upcoming';
  static const overdue = 'Overdue';
  static const completed = 'Completed';

  // Status labels
  static const statusPending = 'Pending';
  static const statusCompletedOnTime = 'On Time';
  static const statusCompletedLate = 'Late';
  static const statusMissed = 'Missed';

  // Completion
  static const completedOnTime = 'Task completed on time!';
  static const completedLate = 'Completed late — good job finishing!';
  static const penaltyApplied = 'Penalty applied';
  static const rewardEarned = 'Reward earned';
  static const penaltyAvoided = 'Penalty avoided';

  // Payments
  static const addPaymentMethod = 'Add Payment Method';
  static const paymentMethod = 'Payment Method';
  static const saveCard = 'Save Card';
  static const skipForNow = 'Skip for now';
  static const cardEndingIn = 'Card ending in';
  static const noPaymentMethod = 'No payment method linked';

  // History
  static const history = 'History';
  static const totalEarned = 'Total Earned';
  static const totalLost = 'Total Lost';
  static const noHistory = 'No transactions yet';

  // Settings
  static const settings = 'Settings';
  static const notifications = 'Notifications';
  static const sound = 'Sound';
  static const haptics = 'Haptics';
  static const signOut = 'Sign Out';
  static const signOutConfirm = 'Are you sure you want to sign out?';

  // Onboarding
  static const onboarding1Title = 'Set tasks, set stakes';
  static const onboarding1Body =
      'Create tasks with real financial consequences. Skin in the game gets things done.';
  static const onboarding2Title = 'Complete on time, earn rewards';
  static const onboarding2Body =
      'Finish before your deadline and earn the reward you set. No app can pay you to focus — but you can.';
  static const onboarding3Title = 'Miss a deadline, pay the price';
  static const onboarding3Body =
      'Set a penalty for procrastination. Because some things are worth holding yourself accountable for.';
  static const getStarted = 'Get Started';
  static const next = 'Next';
  static const skip = 'Skip';

  // Errors
  static const genericError = 'Something went wrong. Please try again.';
  static const networkError = 'Check your connection and try again.';
  static const paymentError = 'Payment failed. Please update your card.';
}
