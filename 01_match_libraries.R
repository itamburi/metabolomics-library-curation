
library(tidyverse)

mycurrentdirectory = dirname(rstudioapi::getActiveDocumentContext()$path)
setwd(mycurrentdirectory)
list.files()


# ---------------------------
# User inputs
# ---------------------------
myname = "Ian"
mytissue = "Serum"           # e.g., Serum, Liver, Heart, etc.
seqdate  = "2022-04"         # approx date of sequence as YYYY-MM
seqname  = "ldlr_serum_apr2022" 

cd_posi_path = "my_input/ldlr_serum_posi.csv" # path to positive mode CD export as .csv
cd_nega_path = "my_input/ldlr_serum_nega.csv" # path to negative mode CD export as .csv
library_path = "metabolites_list_260210.csv" # lab metabolite library path
out_path = paste0(myname,"_",mytissue,"_",seqdate,".csv")


# ---------------------------
# Read inputs
# ---------------------------
cd_posi = read.csv(cd_posi_path)
cd_nega = read.csv(cd_nega_path)
ref_lib = read.csv(library_path)

ref_lib[ref_lib == ""] = NA

mycols = c(
  "Name", "Formula", "Calc..MW", "m.z", "RT..min.",
  "mzCloud.Best.Match", "mzCloud.Best.Match.Confidence",
  "Annot..DeltaMass..ppm."
)

cd1 = cd_posi %>%
  select(all_of(mycols)) %>%
  mutate(ion.mode = "Posi")

cd2 = cd_nega %>%
  select(all_of(mycols)) %>%
  mutate(ion.mode = "Nega")

cd_full = bind_rows(cd1, cd2) %>%
  mutate(
    Name = stringr::str_squish(Name),
    Formula = gsub(" ", "", Formula),
    mzCloud.Best.Match.Confidence = ifelse(is.na(mzCloud.Best.Match.Confidence), 0, mzCloud.Best.Match.Confidence),
    tissue = mytissue,
    seqdate = seqdate,
    seqname = seqname
  ) %>%
  filter(
    !is.na(Name), Name != "",
    !grepl("\\[Similar to:", Name),
    !is.na(Annot..DeltaMass..ppm.),
    abs(Annot..DeltaMass..ppm.) < 30
  )

# Keep best-supported entry per Name/Formula/mode
cd_best = cd_full %>%
  filter(mzCloud.Best.Match.Confidence > 0) %>%
  group_by(Name, Formula, ion.mode) %>%
  arrange(desc(mzCloud.Best.Match.Confidence), abs(Annot..DeltaMass..ppm.), .by_group = TRUE) %>%
  slice(1) %>%
  ungroup() %>%
  rename(
    RT.seq = RT..min.,
    ion.mode.seq = ion.mode
  )

# Prepare reference library
ref_lib2 = ref_lib %>%
  rename(RT.library = RT)

# Explicit join
result = cd_best %>%
  left_join(ref_lib2, by = c("Name", "Formula")) %>%
  mutate(
    RT.diff = RT.seq - RT.library
  ) %>%
  select(
    seqname, seqdate, tissue,
    Name, Formula, ion.mode.seq, m.z,
    RT.seq, RT.library, RT.diff,
    mzCloud.Best.Match, mzCloud.Best.Match.Confidence,
    Annot..DeltaMass..ppm.,
    everything()
  )

write.csv(result, out_path, row.names = FALSE)









