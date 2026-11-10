# build_spec_form.R — embed assets/model_spec_template.md in
# assets/model_spec_form.html, so the form's fields match the template.
# Run from the repository root after any change to the template:
#
#   Rscript scripts/build_spec_form.R
#
# tests/test_toolkit.R fails if the two are out of step.

form_path <- file.path("assets", "model_spec_form.html")
tpl_path <- file.path("assets", "model_spec_template.md")

read_utf8 <- function(p) paste(readLines(p, encoding = "UTF-8", warn = FALSE), collapse = "\n")
form <- read_utf8(form_path)
tpl <- gsub("\r", "", read_utf8(tpl_path))
if (grepl("</script", tpl, ignore.case = TRUE)) stop("Template must not contain '</script'")

open_tag <- "<script type=\"text/plain\" id=\"spec-template\">"
close_tag <- "</script><!--/spec-template-->"
start <- regexpr(open_tag, form, fixed = TRUE)
end <- regexpr(close_tag, form, fixed = TRUE)
if (start < 0 || end < 0) stop("Template markers not found in ", form_path)

new_form <- paste0(substr(form, 1, start + nchar(open_tag) - 1), tpl, "\n",
                   substr(form, end, nchar(form)))
con <- file(form_path, open = "w", encoding = "UTF-8")
writeLines(new_form, con)
close(con)
cat("Embedded", tpl_path, "in", form_path, "\n")
