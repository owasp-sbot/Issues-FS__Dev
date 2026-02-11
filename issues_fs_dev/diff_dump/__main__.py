import argparse
import sys
from issues_fs_dev.diff_dump.Diff_Dump                                          import Diff_Dump


def main():
    parser = argparse.ArgumentParser(
        prog        = 'diff-dump',
        description = 'Generate cross-repo diff dumps between versions/tags of Issues-FS__Dev'
    )
    parser.add_argument('from_ref',                       help='Starting reference (tag, commit, or branch)')
    parser.add_argument('to_ref',   nargs='?', default='HEAD',
                        help='Ending reference (default: HEAD)')
    parser.add_argument('--full-diff',    action='store_true', help='Include full diff content (not just stats)')
    parser.add_argument('--no-stats',     action='store_true', help='Exclude file change statistics')
    parser.add_argument('--modules-only', action='store_true', help='Only diff module repos, skip role repos')
    parser.add_argument('--output', '-o', choices=['stdout', 'clipboard', 'file'], default='stdout',
                        help='Output mode (default: stdout)')
    parser.add_argument('--file',  '-f',  default=None,       help='Output file path (when --output=file)')

    args = parser.parse_args()

    dumper = Diff_Dump()
    output = dumper.generate(
        from_ref          = args.from_ref,
        to_ref            = args.to_ref,
        include_stats     = args.no_stats is False,
        include_full_diff = args.full_diff,
        modules_only      = args.modules_only
    )

    if args.output == 'clipboard':
        if dumper.copy_to_clipboard(output) is True:
            lines = output.count('\n')
            print(f"Copied to clipboard ({lines} lines)")
        else:
            print("Clipboard not available. Printing to stdout instead.\n", file=sys.stderr)
            print(output)
    elif args.output == 'file':
        if args.file is None:
            safe_from = args.from_ref.replace('/', '_')
            safe_to   = args.to_ref.replace('/', '_')
            filename  = f"diff_dump__{safe_from}..{safe_to}.txt"
        else:
            filename = args.file
        with open(filename, 'w') as f:
            f.write(output)
        print(f"Written to {filename}")
    else:
        print(output)


if __name__ == '__main__':
    main()
