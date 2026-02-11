import argparse
import sys
from issues_fs_dev.context_dump.Context_Dump                                    import Context_Dump


def main():
    parser = argparse.ArgumentParser(
        prog        = 'context-dump',
        description = 'Gather relevant source code and docs for an LLM coding session'
    )
    subparsers = parser.add_subparsers(dest='command')

    gather_parser = subparsers.add_parser('gather', help='Gather context for a topic')
    gather_parser.add_argument('topic',                    help='Topic name or keyword to search for')
    gather_parser.add_argument('--no-code',     action='store_true', help='Exclude source code files')
    gather_parser.add_argument('--no-docs',     action='store_true', help='Exclude documentation files')
    gather_parser.add_argument('--include-roles',action='store_true',help='Include relevant ROLE.md files')
    gather_parser.add_argument('--no-types',    action='store_true', help='Exclude Type_Safe docs')
    gather_parser.add_argument('--output', '-o', choices=['stdout', 'clipboard', 'file'], default='stdout',
                               help='Output mode (default: stdout)')
    gather_parser.add_argument('--file',  '-f', default=None,       help='Output file path (when --output=file)')
    gather_parser.add_argument('--max-files',   type=int, default=50, help='Max number of files to include')

    list_parser = subparsers.add_parser('topics', help='List available topics')

    args = parser.parse_args()

    if args.command is None:
        parser.print_help()
        sys.exit(0)

    dumper = Context_Dump()

    if args.command == 'topics':
        topics = dumper.list_topics()
        if len(topics) == 0:
            print("No topics configured in topic_map.json")
            sys.exit(0)
        print(f"{'Topic':<20} Description")
        print(f"{'-'*20} {'-'*50}")
        for name, desc in sorted(topics):
            print(f"{name:<20} {desc}")
        sys.exit(0)

    if args.command == 'gather':
        output = dumper.gather(
            topic         = args.topic,
            include_code  = args.no_code  is False,
            include_docs  = args.no_docs  is False,
            include_roles = args.include_roles,
            include_types = args.no_types is False,
            max_files     = args.max_files
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
                filename = f"context_dump__{args.topic}.txt"
            else:
                filename = args.file
            with open(filename, 'w') as f:
                f.write(output)
            print(f"Written to {filename}")
        else:
            print(output)


if __name__ == '__main__':
    main()
