# GanttProject Bug [523](https://github.com/bardsoftware/ganttproject/issues/523)

## Steps


    1.Enter tasks
    2.Select all tasks
    3.Cut tasks
    4.Try to create a new task

## Patch

```
commit 56746ed6ad37599443271f60d44988032f6a9dde
Author: dbarashev <dbarashev@localhost>
Date:   Thu May 31 01:25:30 2012 +0400

    fixes issue #523 in the trunk

diff --git a/ganttproject/src/net/sourceforge/ganttproject/GanttTree2.java b/ganttproject/src/net/sourceforge/ganttproject/GanttTree2.java
index 12b877a..59c66ba 100644
--- a/ganttproject/src/net/sourceforge/ganttproject/GanttTree2.java
+++ b/ganttproject/src/net/sourceforge/ganttproject/GanttTree2.java
@@ -837,12 +837,9 @@ public class GanttTree2 extends TreeTableContainer<Task, GanttTreeTable, GanttTr
               parent = (MutableTreeTableNode) node.getParent();
               where = parent.getIndex(current);
               removeCurrentNode(current);
-              current.setParent(parent);
               taskFather = (GanttTask) parent.getUserObject();
               AdjustTaskBoundsAlgorithm alg = myTaskManager.getAlgorithmCollection().getAdjustTaskBoundsAlgorithm();
               alg.run(taskFather);
-              // taskFather.refreshDateAndAdvancement(this);
-              parent.setUserObject(taskFather);
             }
           }
           if (parent.getChildCount() == 0) {
diff --git a/ganttproject/src/net/sourceforge/ganttproject/TreeUtil.java b/ganttproject/src/net/sourceforge/ganttproject/TreeUtil.java
index c7fdd30..9b8a29f 100644
--- a/ganttproject/src/net/sourceforge/ganttproject/TreeUtil.java
+++ b/ganttproject/src/net/sourceforge/ganttproject/TreeUtil.java
@@ -12,6 +12,9 @@ import com.google.common.collect.Lists;
 
 public class TreeUtil {
   static int getPrevSibling(TreeNode node, TreeNode child) {
+    if (node == null) {
+      return -1;
+    }
     int childIndex = node.getIndex(child);
     return childIndex - 1;
   }
@@ -23,6 +26,9 @@ public class TreeUtil {
   }
 
   static int getNextSibling(TreeNode node, TreeNode child) {
+    if (node == null) {
+      return -1;
+    }
     int childIndex = node.getIndex(child);
     return childIndex == node.getChildCount() - 1 ? -1 : childIndex + 1;
   }
diff --git a/ganttproject/src/net/sourceforge/ganttproject/task/TaskManagerImpl.java b/ganttproject/src/net/sourceforge/ganttproject/task/TaskManagerImpl.java
index 87037f9..a1b1b98 100644
--- a/ganttproject/src/net/sourceforge/ganttproject/task/TaskManagerImpl.java
+++ b/ganttproject/src/net/sourceforge/ganttproject/task/TaskManagerImpl.java
@@ -303,7 +303,7 @@ public class TaskManagerImpl implements TaskManager {
 
         registerTask(task);
 
-        if (myPrevSibling != null) {
+        if (myPrevSibling != null && myPrevSibling != getRootTask()) {
           int position = getTaskHierarchy().getTaskIndex(myPrevSibling) + 1;
           Task parentTask = getTaskHierarchy().getContainer(myPrevSibling);
           getTaskHierarchy().move(task, parentTask, position);
```
