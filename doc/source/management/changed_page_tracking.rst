.. _changed_page_tracking:

=============================
XtraDB changed page tracking
=============================

XtraDB now tracks the pages that have changes written to them according to the redo log. This information is written out in a special changed page bitmap file.  This information can be used to speed up incremental backups using `Percona XtraBackup <http://www.percona.com/doc/percona-xtrabackup/>`_, by removing the need to scan whole data files to find the changed pages. This change tracking is done by a new XtraDB worker thread that reads and parses log records between checkpoints. The tracking is controlled by a new read-only server variable :variable:`innodb_track_changed_pages`.

This feature will be used for implementing faster incremental backups that use this information to avoid full data scans in |Percona XtraBackup|.

Additional information in SHOW ENGINE INNODB STATUS
===================================================
When log tracking is enabled, the following additional fields are displayed in the LOG section of the ``SHOW ENGINE INNODB STATUS`` output:

 * "Log tracked up to:" displays the LSN up to which all the changes have been parsed and stored as a bitmap on disk by the log tracking thread
 * "Max tracked LSN age:" displays the maximum limit on how far behind the log tracking thread may be.

INFORMATION_SCHEMA Tables
=========================

This table contains a list of modified pages from the bitmap file data.  As these files are generated by the log tracking thread parsing the log whenever the checkpoint is made, it is not real-time data.

.. table:: INFORMATION_SCHEMA.INNODB_CHANGED_PAGES

   :column INT(11) space_id: space id of modified page
   :column INT(11) page_id: id of modified page
   :column BIGINT(21) start_lsn: start of the interval
   :column BIGINT(21) end_lsn: end of the interval 

The ``start_lsn`` and the ``end_lsn`` columns denote between which two checkpoints this page was changed at least once. They are also equal to checkpoint LSNs.

System Variables
================

.. variable:: innodb_track_changed_pages

   :version 5.1.65-14.0: Variable introduced
   :cli: Yes
   :conf: Yes
   :scope: Global
   :dyn: No
   :vartype: Boolean
   :default: 0 - False
   :range: 0-1
