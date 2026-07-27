"""
title: Date and Time Operations
author: Eugene Beauzec
version: 0.1.0
license: Proprietary
description: Operations for dates, times, and timezones.

Copyright: (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
"""

import datetime
from pydantic import BaseModel

class Tools:
    class Valves(BaseModel):
        pass
        
    def __init__(self):
        self.valves = self.Valves()
        
    async def current_datetime(self, __user__: dict = {}) -> str:
        """Get the current local date and time.
        
        :return: Current datetime in ISO format.
        """
        now = datetime.datetime.now(datetime.timezone.utc).astimezone()
        return f"Current local time: {now.isoformat()}"
        
    async def date_difference(self, date1: str, date2: str, __user__: dict = {}) -> str:
        """Calculate the difference between two dates.
        
        :param date1: First date (ISO format like YYYY-MM-DD or YYYY-MM-DDTHH:MM:SS).
        :param date2: Second date (ISO format).
        :return: Difference in days, hours, minutes, and seconds.
        """
        try:
            d1 = datetime.datetime.fromisoformat(date1.replace('Z', '+00:00'))
            d2 = datetime.datetime.fromisoformat(date2.replace('Z', '+00:00'))
            
            diff = abs(d1 - d2)
            days = diff.days
            seconds = diff.seconds
            
            hours = seconds // 3600
            minutes = (seconds % 3600) // 60
            secs = seconds % 60
            
            return f"Difference: {days} days, {hours} hours, {minutes} minutes, {secs} seconds"
        except Exception as e:
            return f"Error calculating difference: {str(e)}"

    async def add_time(self, date: str, days: int = 0, hours: int = 0, minutes: int = 0, __user__: dict = {}) -> str:
        """Add time to a given date. Use negative numbers to subtract.
        
        :param date: The starting date in ISO format.
        :param days: Number of days to add.
        :param hours: Number of hours to add.
        :param minutes: Number of minutes to add.
        :return: The new calculated date in ISO format.
        """
        try:
            d = datetime.datetime.fromisoformat(date.replace('Z', '+00:00'))
            delta = datetime.timedelta(days=days, hours=hours, minutes=minutes)
            new_date = d + delta
            return f"Calculated date: {new_date.isoformat()}"
        except Exception as e:
            return f"Error adding time: {str(e)}"

    async def format_date(self, date: str, format_str: str, __user__: dict = {}) -> str:
        """Format a date string according to a strftime format pattern.
        
        :param date: The date in ISO format.
        :param format_str: The strftime format string (e.g., '%Y-%m-%d %H:%M:%S').
        :return: The formatted date string.
        """
        try:
            d = datetime.datetime.fromisoformat(date.replace('Z', '+00:00'))
            return d.strftime(format_str)
        except Exception as e:
            return f"Error formatting date: {str(e)}"
            
    async def timezone_convert(self, datetime_str: str, from_tz_offset: str, to_tz_offset: str, __user__: dict = {}) -> str:
        """Convert a time between timezone offsets.
        Note: Using offsets like '+04:00' or '-05:00' due to standard library limitations with timezone names.
        
        :param datetime_str: The date and time (e.g. '2025-01-01T12:00:00').
        :param from_tz_offset: The original timezone offset (e.g. '+00:00', '-08:00').
        :param to_tz_offset: The target timezone offset (e.g. '+04:00').
        :return: The converted datetime.
        """
        try:
            # Simple offset parsing
            def parse_tz(offset_str):
                sign = 1 if offset_str[0] == '+' else -1
                h, m = map(int, offset_str[1:].split(':'))
                return datetime.timezone(datetime.timedelta(hours=sign*h, minutes=sign*m))
                
            dt = datetime.datetime.fromisoformat(datetime_str)
            if dt.tzinfo is None:
                from_tz = parse_tz(from_tz_offset)
                dt = dt.replace(tzinfo=from_tz)
                
            to_tz = parse_tz(to_tz_offset)
            target_dt = dt.astimezone(to_tz)
            return f"Converted: {target_dt.isoformat()}"
        except Exception as e:
            return f"Error converting timezone: {str(e)}"
