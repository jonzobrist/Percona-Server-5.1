/*
   Copyright (c) 2000, 2001, 2004, 2006, 2007 MySQL AB, 2009 Sun Microsystems, Inc.
   Use is subject to license terms.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; version 2 of the License.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301  USA
*/

#include "mysys_priv.h"
#include "mysys_err.h"
#include <errno.h>
#ifdef HAVE_PREAD
#include <unistd.h>
#endif

/*
  Read a chunk of bytes from a file from a given position

  SYNOPSIOS
    my_pread()
    Filedes	File decsriptor
    Buffer	Buffer to read data into
    Count	Number of bytes to read
    offset	Position to read from
    MyFlags	Flags

  NOTES
    This differs from the normal pread() call in that we don't care
    to set the position in the file back to the original position
    if the system doesn't support pread().

  RETURN
    (size_t) -1   Error
    #             Number of bytes read
*/

size_t my_pread(File Filedes, uchar *Buffer, size_t Count, my_off_t offset,
                myf MyFlags)
{
  size_t readbytes;
  size_t total_readbytes= 0;
  int error= 0;
  DBUG_ENTER("my_pread");
  DBUG_PRINT("my",("Fd: %d  Seek: %lu  Buffer: 0x%lx  Count: %u  MyFlags: %d",
		   Filedes, (ulong) offset, (long) Buffer, (uint) Count,
                   MyFlags));
  for (;;)
  {
#ifndef __WIN__
    errno=0;					/* Linux doesn't reset this */
#endif
#ifndef HAVE_PREAD
    pthread_mutex_lock(&my_file_info[Filedes].mutex);
    readbytes= (uint) -1;
    error= (lseek(Filedes, offset, MY_SEEK_SET) == (my_off_t) -1 ||
	    (readbytes= read(Filedes, Buffer, (uint) Count)) != Count);
    pthread_mutex_unlock(&my_file_info[Filedes].mutex);
#else
    if ((error= ((readbytes= pread(Filedes, Buffer, Count, offset)) != Count)))
      my_errno= errno ? errno : -1;
#endif
    if (readbytes > 0)
      total_readbytes+= readbytes;

    if (error || readbytes != Count)
    {
      DBUG_PRINT("warning",("Read only %d bytes off %u from %d, errno: %d",
                            (int) readbytes, (uint) Count,Filedes,my_errno));
#ifdef THREAD
      if ((readbytes == 0 || readbytes == (size_t) -1) && errno == EINTR)
      {
        DBUG_PRINT("debug", ("my_pread() was interrupted and returned %d",
                             (int) readbytes));
        continue;                              /* Interrupted */
      }
#endif
      if (readbytes > 0 && readbytes < Count && errno == 0)
      {
        /*
          pread() may return less bytes than requested even if enough bytes are
          available according to the Linux man page.
          This makes determining the end-of-file condition a bit harder.
          We just do another pread() call to see if more bytes can be read,
          since all my_pread() users expect it to always return all available
          bytes. For end-of-file 0 bytes is returned. This can never be the case
          for a partial read, since according to the man page, -1 is returned
          with errno set to EINTR if no data has been read.
        */
        Buffer+= readbytes;
        offset+= readbytes;
        Count-= readbytes;

        continue;
      }
      if (MyFlags & (MY_WME | MY_FAE | MY_FNABP))
      {
	if (readbytes == (size_t) -1)
	  my_error(EE_READ, MYF(ME_BELL+ME_WAITTANG),
		   my_filename(Filedes),my_errno);
	else if (MyFlags & (MY_NABP | MY_FNABP))
	  my_error(EE_EOFERR, MYF(ME_BELL+ME_WAITTANG),
		   my_filename(Filedes),my_errno);
      }
      if (readbytes == (size_t) -1 || (MyFlags & (MY_FNABP | MY_NABP)))
	DBUG_RETURN(MY_FILE_ERROR);		/* Return with error */
    }
    if (MyFlags & (MY_NABP | MY_FNABP))
      DBUG_RETURN(0);				/* Read went ok; Return 0 */
    DBUG_RETURN(total_readbytes);			/* purecov: inspected */
  }
} /* my_pread */


/*
  Write a chunk of bytes to a file at a given position

  SYNOPSIOS
    my_pwrite()
    Filedes	File decsriptor
    Buffer	Buffer to write data from
    Count	Number of bytes to write
    offset	Position to write to
    MyFlags	Flags

  NOTES
    This differs from the normal pwrite() call in that we don't care
    to set the position in the file back to the original position
    if the system doesn't support pwrite()

  RETURN
    (size_t) -1   Error
    #             Number of bytes read
*/

size_t my_pwrite(int Filedes, const uchar *Buffer, size_t Count,
                 my_off_t offset, myf MyFlags)
{
  size_t writenbytes, written;
  uint errors;
  DBUG_ENTER("my_pwrite");
  DBUG_PRINT("my",("Fd: %d  Seek: %lu  Buffer: 0x%lx  Count: %u  MyFlags: %d",
		   Filedes, (ulong) offset, (long) Buffer, (uint) Count,
                   MyFlags));
  errors= 0;
  written= 0;

  for (;;)
  {
#ifndef HAVE_PREAD
    int error;
    writenbytes= (size_t) -1;
    pthread_mutex_lock(&my_file_info[Filedes].mutex);
    error= (lseek(Filedes, offset, MY_SEEK_SET) != (my_off_t) -1 &&
            (writenbytes = write(Filedes, Buffer, (uint) Count)) == Count);
    pthread_mutex_unlock(&my_file_info[Filedes].mutex);
    if (error)
      break;
#else
    if ((writenbytes= pwrite(Filedes, Buffer, Count,offset)) == Count)
      break;
    my_errno= errno;
#endif
    if (writenbytes != (size_t) -1)
    {					/* Safegueard */
      written+=writenbytes;
      Buffer+=writenbytes;
      Count-=writenbytes;
      offset+=writenbytes;
    }
    DBUG_PRINT("error",("Write only %u bytes", (uint) writenbytes));
#ifndef NO_BACKGROUND
#ifdef THREAD
    if (my_thread_var->abort)
      MyFlags&= ~ MY_WAIT_IF_FULL;		/* End if aborted by user */
#endif
    if ((my_errno == ENOSPC || my_errno == EDQUOT) &&
        (MyFlags & MY_WAIT_IF_FULL))
    {
      wait_for_free_space(my_filename(Filedes), errors);
      errors++;
      continue;
    }
    if ((writenbytes && writenbytes != (size_t) -1) || my_errno == EINTR)
      continue;					/* Retry */
#endif
    if (MyFlags & (MY_NABP | MY_FNABP))
    {
      if (MyFlags & (MY_WME | MY_FAE | MY_FNABP))
      {
	my_error(EE_WRITE, MYF(ME_BELL | ME_WAITTANG),
		 my_filename(Filedes),my_errno);
      }
      DBUG_RETURN(MY_FILE_ERROR);		/* Error on read */
    }
    else
      break;					/* Return bytes written */
  }
  DBUG_EXECUTE_IF("check", my_seek(Filedes, -1, SEEK_SET, MYF(0)););
  if (MyFlags & (MY_NABP | MY_FNABP))
    DBUG_RETURN(0);			/* Want only errors */
  DBUG_RETURN(writenbytes+written); /* purecov: inspected */
} /* my_pwrite */
