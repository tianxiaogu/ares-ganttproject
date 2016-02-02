# GanttProject Bug [607](https://github.com/bardsoftware/ganttproject/issues/607)

## Steps

1. Run `run.sh <gantthome> bug.gan`
2. Create a new task.
3. SBET and FTER can successfully to create new task, but VOER and FER cannot.

First, the NPE is transformed into XNIException, which is a runtime exception but can be handled
by an error handler in `com.sun.org.apache.xerces.internal.parsers.AbstractSAXParser.parse`.
This error handler transforms the XNIException into a SAXException.
Finally, the error handler in GanttXMLOpen will catch and transform this SAXException into an IOException.

## Patch

```
commit a9b9c6984040535cc1ac06c3982abad157832113
Author: dbarashev <dbarashev@localhost>
Date:   Fri Oct 19 02:14:48 2012 +0400

    applied patch for issue #607
    
    Update issue #607

diff --git a/ganttproject/src/net/sourceforge/ganttproject/io/GanttXMLOpen.java b/ganttproject/src/net/sourceforge/ganttproject/io/GanttXMLOpen.java
index 966ae40..61239b5 100644
--- a/ganttproject/src/net/sourceforge/ganttproject/io/GanttXMLOpen.java
+++ b/ganttproject/src/net/sourceforge/ganttproject/io/GanttXMLOpen.java
@@ -113,6 +113,11 @@ public class GanttXMLOpen implements GPParser {
         e.printStackTrace(System.err);
       }
       throw new IOException(e.getMessage());
+    } catch (RuntimeException e) {
+      if (!GPLogger.log(e)) {
+        e.printStackTrace(System.err);
+      }
+      throw new IOException(e.getMessage());
     }
     myTaskManager.getAlgorithmCollection().getRecalculateTaskScheduleAlgorithm().setEnabled(true);
     myTaskManager.getAlgorithmCollection().getAdjustTaskBoundsAlgorithm().setEnabled(true);
```
