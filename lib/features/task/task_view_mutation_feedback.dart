const taskViewReadOnlyMessage = '当前清单为只读，无法修改任务';

bool isTaskViewReadOnlyError(Object error) {
  return error is StateError && error.message == taskViewReadOnlyMessage;
}

String taskViewMutationFailureMessage(Object error, String fallback) {
  return isTaskViewReadOnlyError(error) ? taskViewReadOnlyMessage : fallback;
}
