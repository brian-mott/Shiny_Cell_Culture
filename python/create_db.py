"""
Class for creation and maintenance of sqlite database for organoid app
"""

from sqlalchemy import create_engine, MetaData, Table, Column, Integer, DECIMAL, String, DATE
from sqlalchemy import insert, select
import json
from datetime import datetime


class Database:

    def __init__(self, dbfile, echo=True):
        self.db = dbfile
        self.echo = echo

        self.engine = create_engine(f'sqlite:///{self.db}', echo=self.echo)
        self.meta = MetaData()

        # create tables
        self.culture_containers_table = Table(
            'culturecontainers', self.meta,
            Column('id', Integer, primary_key=True),
            Column('vessel', String),
            Column('perplate', Integer),
            Column('surfaceareacm2', Integer),
            Column('vitronectinml', DECIMAL(5, 1)),
            Column('dpbsml', DECIMAL(5, 1)),
            Column('edtaml', DECIMAL(5, 1)),
            Column('completemediaml', DECIMAL(5, 1)),
            Column('seedingdensity', Integer),
            Column('cellsatconfluency', Integer),
        )

        self.key_days_table = Table(
            'keydaystable', self.meta,
            Column('id', Integer, primary_key=True),
            Column('keyday', Integer),
            Column('notes', String),
        )

        self.media_change_table = Table(
            'mediachange', self.meta,
            Column('id', Integer, primary_key=True),
            Column('day', Integer),
            Column('change', String),
        )

        self.media_reagents_table = Table(
            'mediareagents', self.meta,
            Column('id', Integer, primary_key=True),
            Column('component', String),
            Column('stock', Integer),
            Column('unit', String),
            Column('daystart', Integer),
            Column('dayend', Integer),
            Column('mediasubtract', Integer),
        )

        self.media_volume_table = Table(
            'mediavolume', self.meta,
            Column('id', Integer, primary_key=True),
            Column('volume', Integer),
            Column('daystart', Integer),
            Column('dayend', Integer),
        )

        self.culture_startdates_table = Table(
            'culturestartdates', self.meta,
            Column('id', Integer, primary_key=True),
            Column('batch', Integer),
            Column('day-2', DATE),
            Column('day-1', DATE),
            Column('day0', DATE),
            Column('plates', Integer),
            Column('cellline', String),
        )

        self.plate_inventory_table = Table(
            'plateinventory', self.meta,
            Column('id', Integer, primary_key=True),
            Column('batch', Integer),
            Column('plate', Integer),
            Column('startdateday0', DATE),
            Column('enddate', DATE),
            Column('notes', String),
            Column('medianotes', String),
        )

        # create tables if none exist
        self.meta.create_all(self.engine)


    def load_initial_data(self, json_file):
        """Method to load media, reagent, and key days data"""
        # list of tuples, (class variable name, sqlite table name)
        tables_to_load = [
            (self.culture_containers_table, 'culturecontainers'),
            (self.key_days_table, 'keydaystable'),
            (self.media_change_table, 'mediachange'),
            (self.media_reagents_table, 'mediareagents'),
            (self.media_volume_table, 'mediavolume'),
            (self.culture_startdates_table, 'culturestartdates'),
            (self.plate_inventory_table, 'plateinventory'),
        ]

        # json import needs date hook to get datetime format
        def date_hook(json_dict):
            for (key, value) in json_dict.items():
                try:
                    json_dict[key] = datetime.strptime(value, "%Y-%m-%d")
                except:
                    pass
            return json_dict

        # load json file
        with open(json_file, 'r') as f:
            db_data = json.load(f, object_hook=date_hook)

        # check each table for data and load if empty
        with self.engine.connect() as conn:
            for table in tables_to_load:
                result = conn.execute(select(table[0]))
                check = result.first()
            
                if check is None:
                    conn.execute(insert(table[0]).values(db_data.get(table[1])))
                    conn.commit()
                    print(f'Table {table[1]} is empty, added data')
                else:
                    print(f'Table {table[1]} contains data, nothing inserted')



if __name__ == '__main__':

    # pass argument to Database() for db name and location
    db = Database('data.db')

    # path to JSON file with data to load
    db.load_initial_data('data/initialdbdata.json')