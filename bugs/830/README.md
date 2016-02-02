# GanttProject Bug [830](https://github.com/bardsoftware/ganttproject/issues/830)

## Steps

1. Open the buggy file

## Patch

```
commit 0c6e184eaff7f73293ddce026ac41ef9c7f45e3a
Author: Dmitry Barashev <dbarashev@ganttproject.biz>
Date:   Fri Nov 15 04:18:01 2013 +0400

    scheduler bugfix
    Update issue #830

diff --git a/ganttproject-tester/test/net/sourceforge/ganttproject/task/algorithm/SchedulerTest.java b/ganttproject-tester/test/net/sourceforge/ganttproject/task/algorithm/SchedulerTest.java
index e1c9da5..4d9c5ed 100644
--- a/ganttproject-tester/test/net/sourceforge/ganttproject/task/algorithm/SchedulerTest.java
+++ b/ganttproject-tester/test/net/sourceforge/ganttproject/task/algorithm/SchedulerTest.java
@@ -114,6 +114,32 @@ public class SchedulerTest extends TaskTestCase {
     assertEquals(TestSetupHelper.newWendesday(), tasks[0].getEnd());
   }
 
+  public void test_issue830() throws Exception {
+    // The reason of exception being throws was the following task configuration
+    //    su mo tu we
+    // t0 ==             t0 -> t1 FS
+    // t1    ========    t1 is a supertask of t2
+    // t2       =====    t2 is a supertask of t3 and t4
+    // t3    ==          bounds of t3 and t4 for some reasons are not aligned with t2 bounds
+    // t4    ==
+    //
+    // Scheduler tried to calculate an intersection of t2 dates range and t3+t4 dates range and failed.
+    getTaskManager().getAlgorithmCollection().getRecalculateTaskScheduleAlgorithm().setEnabled(false);
+    Task[] tasks = new Task[] {createTask(TestSetupHelper.newSunday()), createTask(TestSetupHelper.newMonday(), 3), createTask(TestSetupHelper.newWendesday()), createTask(TestSetupHelper.newMonday())};
+    TaskDependency[] deps = new TaskDependency[] { createDependency(tasks[1], tasks[0]) };
+
+    DependencyGraph graph = createGraph(tasks, deps);
+    DependencyGraphTest.move(tasks[2], tasks[1], graph);
+    graph.move(tasks[3], tasks[2]);
+
+    SchedulerImpl scheduler = new SchedulerImpl(graph, Suppliers.ofInstance(getTaskManager().getTaskHierarchy()));
+    scheduler.run();
+    assertEquals(TestSetupHelper.newMonday(), tasks[2].getStart());
+    assertEquals(TestSetupHelper.newMonday(), tasks[3].getStart());
+    assertEquals(TestSetupHelper.newTuesday(), tasks[2].getEnd());
+    assertEquals(TestSetupHelper.newTuesday(), tasks[3].getEnd());
+  }
+
   public void testRubberDependency() throws Exception {
     Task[] tasks = new Task[] {createTask(TestSetupHelper.newMonday()), createTask(TestSetupHelper.newMonday()), createTask(TestSetupHelper.newWendesday())};
     TaskDependency dep10 = getTaskManager().getDependencyCollection().createDependency(tasks[1], tasks[0], new FinishStartConstraintImpl(), TaskDependency.Hardness.RUBBER);
diff --git a/ganttproject/src/net/sourceforge/ganttproject/task/algorithm/SchedulerImpl.java b/ganttproject/src/net/sourceforge/ganttproject/task/algorithm/SchedulerImpl.java
index 3a37cfe..38f2fe5 100644
--- a/ganttproject/src/net/sourceforge/ganttproject/task/algorithm/SchedulerImpl.java
+++ b/ganttproject/src/net/sourceforge/ganttproject/task/algorithm/SchedulerImpl.java
@@ -104,82 +104,94 @@ public class SchedulerImpl extends AlgorithmBase {
     for (int i = 1; i < layers; i++) {
       Collection<Node> layer = myGraph.getLayer(i);
       for (Node node : layer) {
-        Range<Date> startRange = Range.all();
-        Range<Date> endRange = Range.all();
+        try {
+          schedule(node);
+        } catch (IllegalArgumentException e) {
+          GPLogger.log(e);
+        }
+      }
+    }
+  }
 
-        Range<Date> weakStartRange = Range.all();
-        Range<Date> weakEndRange = Range.all();
+  private void schedule(Node node) {
+    Range<Date> startRange = Range.all();
+    Range<Date> endRange = Range.all();
 
-        List<Date> subtaskRanges = Lists.newArrayList();
-        List<DependencyEdge> incoming = node.getIncoming();
-        for (DependencyEdge edge : incoming) {
-          if (!edge.refresh()) {
-            continue;
-          }
-          if (edge instanceof ImplicitSubSuperTaskDependency) {
-            subtaskRanges.add(edge.getStartRange().upperEndpoint());
-            subtaskRanges.add(edge.getEndRange().lowerEndpoint());
-          } else {
-            if (edge.isWeak()) {
-              weakStartRange = weakStartRange.intersection(edge.getStartRange());
-              weakEndRange = weakEndRange.intersection(edge.getEndRange());
-            } else {
-              startRange = startRange.intersection(edge.getStartRange());
-              endRange = endRange.intersection(edge.getEndRange());
-            }
-          }
-          if (startRange.isEmpty() || endRange.isEmpty()) {
-            GPLogger.logToLogger("both start and end ranges were calculated as empty for task=" + node.getTask() + ". Skipping it");
-          }
-        }
+    Range<Date> weakStartRange = Range.all();
+    Range<Date> weakEndRange = Range.all();
 
-        if (!startRange.equals(Range.all())) {
-          startRange = startRange.intersection(weakStartRange);
-        } else if (!weakStartRange.equals(Range.all())) {
-          startRange = weakStartRange.intersection(Range.downTo(node.getTask().getStart().getTime(), BoundType.CLOSED));
-        }
-        if (!endRange.equals(Range.all())) {
-          endRange = endRange.intersection(weakEndRange);
-        } else if (!weakEndRange.equals(Range.all())) {
-          endRange = weakEndRange.intersection(Range.upTo(node.getTask().getEnd().getTime(), BoundType.CLOSED));
-        }
-        if (node.getTask().getThirdDateConstraint() == TaskImpl.EARLIESTBEGIN && node.getTask().getThird() != null) {
-          startRange = startRange.intersection(Range.downTo(node.getTask().getThird().getTime(), BoundType.CLOSED));
-        }
-        if (!subtaskRanges.isEmpty()) {
-          Range<Date> subtasks = Range.encloseAll(subtaskRanges);
-          startRange = startRange.intersection(subtasks);
-          endRange = endRange.intersection(subtasks);
-        }
-        if (startRange.hasLowerBound()) {
-          modifyTaskStart(node.getTask(), startRange.lowerEndpoint());
+    List<Date> subtaskRanges = Lists.newArrayList();
+    List<DependencyEdge> incoming = node.getIncoming();
+    for (DependencyEdge edge : incoming) {
+      if (!edge.refresh()) {
+        continue;
+      }
+      if (edge instanceof ImplicitSubSuperTaskDependency) {
+        subtaskRanges.add(edge.getStartRange().upperEndpoint());
+        subtaskRanges.add(edge.getEndRange().lowerEndpoint());
+      } else {
+        if (edge.isWeak()) {
+          weakStartRange = weakStartRange.intersection(edge.getStartRange());
+          weakEndRange = weakEndRange.intersection(edge.getEndRange());
+        } else {
+          startRange = startRange.intersection(edge.getStartRange());
+          endRange = endRange.intersection(edge.getEndRange());
         }
-        if (endRange.hasUpperBound()) {
-          GPCalendar cal = node.getTask().getManager().getCalendar();
-          Date endDate = endRange.upperEndpoint();
-          TimeUnit timeUnit = node.getTask().getDuration().getTimeUnit();
-          if (!cal.isNonWorkingDay(endDate)) {
-            // in case if calculated end date falls on first day after holidays (say, on Monday)
-            // we'll want to modify it a little bit, so that it falls on that holidays start
-            // If we don't do this, it will be done automatically the next time task activities are recalculated,
-            // and thus task end date will keep changing
-            Date closestWorkingEndDate = cal.findClosest(
-                endDate, timeUnit, GPCalendar.MoveDirection.BACKWARD, GPCalendar.DayType.WORKING);
-            Date closestNonWorkingEndDate = cal.findClosest(
-                endDate, timeUnit, GPCalendar.MoveDirection.BACKWARD, GPCalendar.DayType.NON_WORKING, closestWorkingEndDate);
-            // If there is a non-working date between current task end and closest working date
-            // then we're really just after holidays
-            if (closestNonWorkingEndDate != null && closestWorkingEndDate.before(closestNonWorkingEndDate)) {
-              // we need to adjust-right closest working date to position to the very beginning of the holidays interval
-              Date nonWorkingPeriodStart = timeUnit.adjustRight(closestWorkingEndDate);
-              if (nonWorkingPeriodStart.after(node.getTask().getStart().getTime())) {
-                endDate = nonWorkingPeriodStart;
-              }
-            }
+      }
+      if (startRange.isEmpty() || endRange.isEmpty()) {
+        GPLogger.logToLogger("both start and end ranges were calculated as empty for task=" + node.getTask() + ". Skipping it");
+      }
+    }
+
+    Range<Date> subtasksSpan = subtaskRanges.isEmpty() ?
+        Range.closed(node.getTask().getStart().getTime(), node.getTask().getEnd().getTime()) : Range.encloseAll(subtaskRanges);
+    Range<Date> subtreeStartUpwards = subtasksSpan.span(Range.downTo(node.getTask().getStart().getTime(), BoundType.CLOSED));
+    Range<Date> subtreeEndDownwards = subtasksSpan.span(Range.upTo(node.getTask().getEnd().getTime(), BoundType.CLOSED));
+
+    if (!startRange.equals(Range.all())) {
+      startRange = startRange.intersection(weakStartRange);
+    } else if (!weakStartRange.equals(Range.all())) {
+      startRange = weakStartRange.intersection(subtreeStartUpwards);
+    }
+    if (!endRange.equals(Range.all())) {
+      endRange = endRange.intersection(weakEndRange);
+    } else if (!weakEndRange.equals(Range.all())) {
+      endRange = weakEndRange.intersection(subtreeEndDownwards);
+    }
+    if (node.getTask().getThirdDateConstraint() == TaskImpl.EARLIESTBEGIN && node.getTask().getThird() != null) {
+      startRange = startRange.intersection(Range.downTo(node.getTask().getThird().getTime(), BoundType.CLOSED));
+    }
+    if (!subtaskRanges.isEmpty()) {
+      startRange = startRange.intersection(subtasksSpan);
+      endRange = endRange.intersection(subtasksSpan);
+    }
+    if (startRange.hasLowerBound()) {
+      modifyTaskStart(node.getTask(), startRange.lowerEndpoint());
+    }
+    if (endRange.hasUpperBound()) {
+      GPCalendar cal = node.getTask().getManager().getCalendar();
+      Date endDate = endRange.upperEndpoint();
+      TimeUnit timeUnit = node.getTask().getDuration().getTimeUnit();
+      if (!cal.isNonWorkingDay(endDate)) {
+        // in case if calculated end date falls on first day after holidays (say, on Monday)
+        // we'll want to modify it a little bit, so that it falls on that holidays start
+        // If we don't do this, it will be done automatically the next time task activities are recalculated,
+        // and thus task end date will keep changing
+        Date closestWorkingEndDate = cal.findClosest(
+            endDate, timeUnit, GPCalendar.MoveDirection.BACKWARD, GPCalendar.DayType.WORKING);
+        Date closestNonWorkingEndDate = cal.findClosest(
+            endDate, timeUnit, GPCalendar.MoveDirection.BACKWARD, GPCalendar.DayType.NON_WORKING, closestWorkingEndDate);
+        // If there is a non-working date between current task end and closest working date
+        // then we're really just after holidays
+        if (closestNonWorkingEndDate != null && closestWorkingEndDate.before(closestNonWorkingEndDate)) {
+          // we need to adjust-right closest working date to position to the very beginning of the holidays interval
+          Date nonWorkingPeriodStart = timeUnit.adjustRight(closestWorkingEndDate);
+          if (nonWorkingPeriodStart.after(node.getTask().getStart().getTime())) {
+            endDate = nonWorkingPeriodStart;
           }
-          modifyTaskEnd(node.getTask(), endDate);
         }
       }
+      modifyTaskEnd(node.getTask(), endDate);
     }
   }
```
