use std::collections::btree_map::BTreeMap;
use std::fs::File;
use std::error::Error;
use std::process;

fn ranges() -> Vec<std::ops::RangeInclusive<usize>> {
    vec![
        (0..=10),
        (10..=100),
        (100..=1000),
        (1000..=10000),
        (10000..=std::usize::MAX),
    ]
}

fn bucket_sort() -> Result<BTreeMap<usize, u64>, Box<dyn Error>> {
    let mut count = BTreeMap::new();

    let file = File::open("./movie_dataset.csv")?;
    let mut rdr = csv::Reader::from_reader(file);
    for result in rdr.records() {
        // The iterator yields Result<StringRecord, Error>, so we check the
        // error here.
        let record = result?;
        let vote_count_val = record.get(20).unwrap();
        if let Ok(vote_count) = vote_count_val.parse::<usize>() {
            if let Some(pos) = ranges()
                .iter()
                .position(|range| range.contains(&vote_count))
            {
                *count.entry(pos).or_insert(0) += 1;
            }
        }
    }
    Ok(count)
}

fn main() {
    match bucket_sort() {
        Err(err) => {
            println!("error running example: {}", err);
            process::exit(1);
        }
        Ok(count) => {
            for (index, count) in &count {
                let bar = "#".repeat((count / 20).try_into().unwrap());
                println!("{:?}: {} - {}", ranges().get(*index), bar, count);
            }
        }
    }
}
