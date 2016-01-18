# GanttProject Bug [708]()


## Patch

```
commit e1452372614eb006f81dcf8f7861b7292f9cdd9c
Author: dbarashev <dbarashev@localhost>
Date:   Fri Jan 4 16:41:29 2013 +0400

    fixes issue #708

diff --git a/biz.ganttproject.impex.msproject2/src/biz/ganttproject/impex/msproject2/ProjectFileExporter.java b/biz.ganttproject.impex.msproject2/src/biz/ganttproject/impex/msproject2/ProjectFileExporter.java
index e433f57..815bf2f 100644
--- a/biz.ganttproject.impex.msproject2/src/biz/ganttproject/impex/msproject2/ProjectFileExporter.java
+++ b/biz.ganttproject.impex.msproject2/src/biz/ganttproject/impex/msproject2/ProjectFileExporter.java
@@ -422,6 +422,7 @@ class ProjectFileExporter {
     DefaultListModel daysOff = hr.getDaysOff();
     if (!daysOff.isEmpty()) {
       ProjectCalendar resourceCalendar = mpxjResource.addResourceCalendar();
+      resourceCalendar.addDefaultCalendarHours();
       exportWeekends(resourceCalendar);
       resourceCalendar.setBaseCalendar(myOutputProject.getCalendar());
       // resourceCalendar.setUniqueID(hr.getId());
```
