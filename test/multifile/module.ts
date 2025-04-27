import { format, differenceInDays } from "npm:date-fns";

// Only using the format function (differenceInDays will be tree-shaken out)
function formatCurrentDate() {
  const now = new Date();
  // Format: "Monday, January 1, 2023"
  console.log("CHECK THIS");
  return format(now, "EEEE, MMMM d, yyyy");
}

export { formatCurrentDate };